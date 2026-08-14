# Acme IdP / Authorization Server OIDC/OAuth2.1 監査と修正プラン

Status: proposed (2026-06-19) 対象: Acme(唯一の IdP / AS)の discovery / JWKS / UserInfo / token
client authentication 周辺公開 issuer: `https://www.umaxica.app`(ACME_APP)/ `.com` / `.org`

## Context(なぜこの変更をするか)

公開中の Acme について、実測で次の事故耐性ギャップが見つかった。

- **公開 JWKS に `development-acme-app-es384-a` という kid が出ている。** コードを読むと、この
  `"#{Rails.env}-acme-app-es384-a"` 形式の kid を生成するのは `Rails.env.local?` 限定で動く
  `JitSecurityJwtLocalKeysetInstaller`
  だけ(`lib/jit_security_jwt_local_keyset_installer.rb:35`)。つまり本番 www.umaxica.app は **(a)
  local Rails env(development/test)で起動し、`tmp/local_jwt_keysets.json`
  の揮発・自動生成鍵で署名している**か、**(b) 本番 ENV が dev 名の kid を設定している**かのどちらか。どちらも不可。`JitSecurityJwtRegistry.validate_record!`
  はリテラル `"default"`
  kid しか弾かず (`lib/jit_security_jwt_registry.rb:208`)、`development`/`test`/`local`/`fixture`
  系マーカーを検出しない。
- token endpoint の client 認証メソッドが per-client に固定されておらず、`private_key_jwt`
  登録 client が `client_secret`
  を送ると secret パスへ落ちる経路がある(`app/services/oidc_token_exchange_service.rb:59-68`)。
- UserInfo の 401 応答に RFC 6750 必須の `WWW-Authenticate: Bearer` ヘッダが無い。
- UserInfo の claim が `email`/`profile` scope に関係なく `email`/`name`
  を返す(scope 最小化されていない)。
- discovery が `private_key_jwt` を広告しているのに
  `token_endpoint_auth_signing_alg_values_supported` が無い等、メタデータの正直さに小さな穴がある。

目的: 上記を「一気に deploy 可能」な単位で fail-fast /
fail-closed に修正し、外部公開 endpoint の挙動を contract / integration
test で固定する。Acme=IdP/AS、Sign/Core/Base/Palm=RP の境界は崩さない。

## 監査結果サマリ(分類)

| #   | 重大度       | 概要                                                                                                                   | 状態        |
| --- | ------------ | ---------------------------------------------------------------------------------------------------------------------- | ----------- |
| 1   | **Critical** | 公開 JWKS に `development-*` kid。dev/揮発鍵が本番に露出しうる。registry に dev-kid 拒否が無い                         | 要修正      |
| 2   | **High**     | `private_key_jwt` client が `client_secret` で認証できる降格経路                                                       | 要修正      |
| 3   | Medium       | UserInfo 401 に `WWW-Authenticate: Bearer` 欠落 / `insufficient_scope` が 401                                          | 要修正      |
| 4   | Medium       | UserInfo claim が scope(`email`/`profile`)で最小化されていない                                                         | 要修正      |
| 5   | Low          | discovery に `token_endpoint_auth_signing_alg_values_supported` 欠落、ES384-only が private profile と明記されていない | 要修正      |
| 6   | Low(確認)    | `ri` は OIDC contract ではない(localization hint)。issuer/endpoint に混入しない。test で固定                           | test 追加   |
| 7   | OK           | redirect_uri exact match / code 単回使用(row lock)/ PKCE S256 必須 / 機密 client の nil-secret は fail-closed          | test で固定 |

評価方針(ユーザー確定): registry/JWKS を含め全 Finding を今回修正する。署名 alg は
**ES384-only を維持し private profile として明文化**(RS256 は追加しない)。

## 修正設計

### Finding 1 — production-like 環境で dev-shaped kid を fail-fast(Critical)

根本原因は「本番が local Rails env で動いている / dev 名 kid が使われている」。`Rails.env`
自体が信用できないケースなので、判定軸は **Rails.env ではなく boot host 設定**にする。local 開発では
`boot_config.fetch(:hosts).acme_service.host` が `www.app.localhost:3000`、公開デプロイでは
`www.umaxica.app`。既存の
`OidcIssuer.public_host?`(`app/services/oidc_issuer.rb:98`、loopback/localhost を除外)で「公開デプロイか」を判定できる。

実装:

1. `lib/jit_security_jwt_registry.rb` に予約マーカー定数と判定を追加。
   - `RESERVED_ENV_KID_MARKERS = %w(development test local fixture sample example dummy staging).freeze`
   - `public_deployment?` ヘルパ: `boot_config.fetch(:hosts)`
     の acme/sign/core ホスト群のいずれかが非 loopback の公開ホストなら true(`OidcIssuer.public_host?`
     を再利用、循環参照回避のため判定ロジックは registry 内に薄く再実装 or `Jit` 層へ抽出)。
   - `validate_record!`(`:203`)に追加: `public_deployment?` が true のとき、**active kid および
     `record.keys` の全 kid** が `RESERVED_ENV_KID_MARKERS` の語を含むなら `ConfigurationError`
     で boot 失敗。ローカル(`*.localhost`)では従来どおり dev kid を許可。
2. `config/initializers/jwt.rb`: `Rails.env.local?` かつ `public_deployment?`
   の組み合わせ(=公開ホスト設定なのにlocal env で起動)を boot 失敗にする明示ガードを
   `JitSecurityJwtLocalKeysetInstaller.install!`
   呼び出し前に追加。これが今回の実機事故そのものを起動時に大声で落とす本丸。
3. `JitSecurityJwtLocalKeysetInstaller.install!` 冒頭にも防御を一段(`raise`
   if 公開ホスト設定)。installer が ENV を書き換える前に止める。

これにより「production-public
JWKS に development/test/local/fixture を含む kid が出ない」「production 鍵が未設定・dev 流用なら boot
fail」を満たす。鍵 rotation(current/grace/revoked、`issuer_builder` の
`key_state_for`)は既存実装が妥当なので変更しない。

主な対象:

- `lib/jit_security_jwt_registry.rb`(`validate_record!` / 新ヘルパ)
- `config/initializers/jwt.rb`(boot ガード)
- `lib/jit_security_jwt_local_keyset_installer.rb`(install! 防御)

### Finding 2 — client 認証メソッドを per-client に固定(High)

`oidc_token_exchange_service.rb:59-68` の `authenticated_client?` を、登録メソッド(SSOT =
`registered_token_endpoint_auth_method`)で明示 dispatch に変更する。

- `none` 登録(public client): assertion も secret も受け取らない。`public_client_authenticated?`
  (secret/assertion ともに blank)のみ許可。
- `private_key_jwt` 登録: **必ず client_assertion を要求**。`client_secret`
  が送られても secret パスへ落とさず `invalid_client`。
- `client_secret_post` 登録(または明示メソッド): secret のみ許可、assertion は拒否。
- メソッド未登録の static client(`docs_app`
  等)は機密扱いのまま secret 必須(現状維持、nil-secret は既に fail-closed:
  `oidc_client_registry.rb:104`)。ただし「method 未指定」を明示メソッドへ正規化するか、少なくとも secret 経路に限定する。

主な対象: `app/services/oidc_token_exchange_service.rb`。`OidcClientRegistry` 側に
`token_endpoint_auth_method` 正規化ヘルパを足しても良いが、SSOT は client
config に置いたままにする。

### Finding 3 — UserInfo の RFC 6750 準拠ヘッダ / ステータス(Medium)

`app/controllers/acme/{app,com,org}/oauth/userinfos_controller.rb` の `show` を修正:

- `invalid_token` 時: `401` + `WWW-Authenticate: Bearer error="invalid_token"`(token 不在時は
  `WWW-Authenticate: Bearer` のみ、RFC 6750 §3 / §3.1)。
- `insufficient_scope` 時: `403` +
  `WWW-Authenticate: Bearer error="insufficient_scope", scope="openid"`。
- 3 surface で重複するので `AcmeOauthEndpoint`(`app/controllers/concerns/acme_oauth_endpoint.rb`)に
  `render_oauth_bearer_error(error)` ヘルパを追加して DRY 化。`OidcAccessTokenAuthenticator` の
  `Result#error` をそのまま使う。
- access token only / cookie-session fallback 無し / `openid`
  scope 必須は既に満たしている(現状維持)。

### Finding 4 — UserInfo claim の scope 最小化(Medium)

`app/services/oidc_user_info_response.rb` の `attach_profile_claims` を scope 駆動にする。

- `OidcAccessTokenAuthenticator` の成功 `Result` に scope(`payload["scp"]`)を渡す、もしくは `build`
  に `scopes:` 引数を追加。
- `email`/`email_verified` は `email` scope があるときのみ、`name` は `profile`
  scope があるときのみ付与。
- `sub` は常時。`acr`/`amr`/`auth_time` は現状どおり。
- 互換性影響: `email`
  を常時前提にしている RP があれば影響。RP は Sign/Core/Base/Palm のみ(内部)なので実装と同時に確認。discovery の
  `claims_supported` はそのまま(scope に応じて返る claim の母集合として正しい)。

### Finding 5 — discovery のメタデータ正直化(Low)

`app/services/oidc_discovery_document.rb` の hash に追記:

- `token_endpoint_auth_signing_alg_values_supported: ["ES384"]`(`private_key_jwt` 広告との整合)。
- ES384-only が **strict OIDC conformance ではなく private profile** である旨をコメント +
  doc に明記 (RS256 は追加しない、ユーザー確定)。
- 広告済み endpoint(`revoke` / `oidc/logout` / `authorize` / `token` / `userinfo` /
  `jwks`)が実ルートに存在することは確認済み(`config/routes/acme.rb`)。`backchannel_logout_supported: true`
  は `OidcClientRegistry.logout_clients_for_resource_type`
  等の実装と整合するか実装側を再確認し、嘘なら値を落とす。

ドキュメント: `docs/security/` 配下(例 `docs/security/oidc-discovery-profile.md`)に ES384-only
private profile、 `ri` は OIDC contract 外、UserInfo は bearer-only、の 3 点を残す。

### Finding 6 — `ri` を OIDC contract から切り離す(確認 + test 固定)

`ri`(region identifier, jp/us, `app/services/request_context_contract.rb`)は localization
preference。discovery は `BareController` で `ri`
を無視し、issuer/endpoint には混入しない(`oidc_discovery_document.rb` /
`oidc_issuer.rb`)。key 選択は surface(host)由来で `ri` と直交。**コード変更は不要、contract
test で固定**する。

## 追加するテスト

JWKS / registry:

- production-like(公開ホスト設定)で active/published kid が `development|test|local|fixture`
  を含むと `configure!` が `ConfigurationError` で落ちる。
- ローカル(`*.localhost`)では dev kid が許容される(回帰防止、開発体験維持)。
- 公開 JWKS に private JWK フィールド(`d` 等)が含まれない。
- `alg=ES384` / `kty=EC` / `crv=P-384` / `use=sig` / kid 一意。
- JWKS 応答に `Cache-Control`(現状 `expires_in(1.hour, public: true)`)が付く。

Discovery(`curl -i` 相当の integration):

- `issuer == https://www.umaxica.app`、issuer に query/fragment 無し。
- `?ri=jp` 付き discovery でも metadata の issuer/endpoint が不変。
- 広告 endpoint が実在ルートに解決する。
- `token_endpoint_auth_signing_alg_values_supported == ["ES384"]`、`id_token_signing_alg_values_supported == ["ES384"]`。

Token endpoint(regression):

- confidential client + `none` → 拒否。
- public client + no PKCE / plain PKCE → 拒否、S256 + exact redirect_uri → 許可。
- redirect_uri mismatch / code 再利用 / expired code / wrong client_id → 拒否。
- **`private_key_jwt` client が `client_secret` を送っても拒否**(Finding 2 の核)。
- `client_secret_post` client が assertion を送っても登録メソッド外として扱う。

UserInfo(`curl -i` 相当 integration):

- no token → 401 + `WWW-Authenticate: Bearer`。
- malformed / expired / wrong issuer / wrong audience / revoked → 401 + ヘッダ。
- insufficient scope(`openid` 無し)→ 403 + `WWW-Authenticate: Bearer error="insufficient_scope"`。
- ID token を bearer にしても通らない / cookie session のみでは通らない。
- `email` scope 無しで email claim を返さない / `profile` scope 無しで name を返さない。

既存テスト確認: `test/controllers/acme/oauth_oidc_authority_test.rb`、
`test/services/oidc/token_exchange_service_test.rb`、`test/services/oidc/access_token_authenticator_*`
等を壊さないこと。

## 検証手順

```sh
bin/rails routes | grep -E 'oauth|oidc|well-known|jwks|userinfo|token|authorize|revoke'
# narrow first
bin/rails test test/services/oidc/ test/controllers/acme/
bin/rails test test/unit/jit/security/jwt/
# broader
bin/rails test test/
bundle exec rubocop
bundle exec brakeman
```

JS 側変更は想定なし(`pnpm test` 不要)。public endpoint は test 環境で公開ホスト設定を擬似し、
`get` + ヘッダ assertion で `curl -i` 相当を固定する。

## スコープ外 / 注意

- **デプロイ環境の修正そのもの**(本番を production Rails
  env で起動し、本番管理鍵を ENV 投入)はインフラ作業でコード外。本プランは「起動時に fail-fast させる防御」をコードに入れるところまで。実機の ENV
  / RAILS_ENV 是正は別途運用対応が必要(報告で明記)。
- `jwt-jwks-security-review-followups.md`
  の他 in-flight 作業との衝突可能性: ユーザー了承のうえ進行。registry 変更は `validate_record!`
  への追加と新ヘルパに限定し、既存 rotation/codec 構造は触らない。
- Acme=IdP/AS、Sign=RP の境界、token authority(`adr/acme-session-and-token-authority.md`)は不変。
- 非英語の committed 文書は本プランのみ日本語(ユーザー方針)。コード識別子・コメント・test 名は英語。

## 実装レビュー結果(2026-06-19)と要修正

初回実装をレビューした結果、Finding 2/3/4 は良好、Finding 5 は一部、**Finding
1 は実質無効**。以下を修正する。

### [Critical] Finding 1: `public_deployment?` の env gate を除去し host 判定を正す

現状(`lib/jit_security_jwt_registry.rb` / `lib/jit_security_jwt_local_keyset_installer.rb`):

```ruby
def public_deployment?
  return false unless Rails.env.production?   # ← 目的を破壊
  ...
end
def public_host?(host)
  ...
rescue IPAddr::InvalidAddressError
  uri.host.present? && uri.host != "localhost"  # ← *.localhost を public 誤判定
end
```

問題:

1. 実機事故は `Rails.env=development` + public
   host で発生するため、`return false unless Rails.env.production?`
   だと予約 kid チェックがスキップされ
   **boot 成功・dev 鍵公開のまま**。コメント (「discriminator は Rails.env ではなく host」)と実装が矛盾。
2. installer ガード `if Rails.env.development? && public_deployment?` は
   `development? && production?` となり**恒偽=デッドコード**。
3. 既存テストは対象メソッド `public_deployment?` を `stub(true/false)`
   でバイパスしており実ロジック未検証。

修正:

- `public_host?` を repo 既存方式(loopback トークンの部分一致)に統一。registry に定義済みで未使用の
  `PUBLIC_DEPLOYMENT_LOOPBACK_TOKENS = %w(localhost 127.0.0.1 ::1)` を使い
  `tokens.none? { |t| host.include?(t) }` 判定にする。`*.localhost` は `include?("localhost")`
  で正しく非 public になる。既存の `OidcIssuer.public_host?` / `OidcClientRegistry.public_host?` /
  `OidcClientStoresStaticClientStore.public_host?` と整合。
- `public_deployment?` から `return false unless Rails.env.production?` を**削除**。これで「dev
  env + public host(実機事故)」と「prod env + dev kid」の両方を捕捉、localhost 開発のみ許容。
- installer ガードを `if public_deployment?`(または `Rails.env.local? && public_deployment?`)に。
- registry/installer テストは `public_deployment?`
  のスタブをやめ、`Rails.configuration.x.boot_config` に public hosts / local
  hosts を実際に注入して**実ロジックを検証**する。

### [回帰確認] Finding 2: 既存ハッピーパステストの assertion 受け渡し

`with_authenticated_client` を `authenticate_assertion` スタブへ切替済み。`core-next-rp` は
`private_key_jwt` なので、既存テストが request に `client_assertion`/`client_assertion_type`
を渡していないと `authenticated_client_assertion?` の `return false if client_assertion.blank?`
で全て invalid_client になる。`bin/rails test test/services/oidc/token_exchange_service_test.rb`
を流して緑を確認(必要なら各 call site に assertion を付与)。

### [軽微] Finding 3: no-token は bare `Bearer`

`OidcAccessTokenAuthenticator` は token 不在でも `invalid_token` を返すため、現状 no-token でも
`Bearer error="invalid_token"`。RFC 6750 §3 に厳密に合わせるなら token 完全不在時は bare
`Bearer`。controller 側で `request`
の Authorization 不在を見て分岐するか、許容範囲として doc 化する(合格条件は充足)。

### [未実装] Finding 5: discovery profile ドキュメント

`docs/security/oidc-discovery-profile.md` を作成: ES384-only は strict OIDC conformance ではなく
**private profile**、`ri` は OIDC contract 外、UserInfo は bearer access token
only、の 3 点を明文化 (ユーザー選択「ES384のみ維持＋明文化」)。

### [未実装] Finding 6: `ri` contract test

discovery integration テストに、`?ri=jp` 付きでも
`issuer == https://www.umaxica.app`(query/fragment無し)・endpoints 不変、を固定するケースを追加。

## 修正2 (2026-06-19 PM): development boot 回帰の是正

### 問題

host ベースの `public_deployment?` ガードが、`.env` で `ACME_SERVICE_URL=www.umaxica.app` 等の
**公開ホストを development で使っているこのボックス**で発火し、`bin/rails s`(development)が
`local JWT keyset installer must not run for a public deployment` で起動不能になった。
`JWT_ALLOW_LOCAL_KEYSET_FOR_PUBLIC_HOST` opt-in は摩擦が大きく、設計が過剰だった。

### 是正方針(簡素化)

判定軸を「public host」から **`Rails.env.local?`(development/test のみ true)**
に変更する。非 local 環境(production / staging / review /
container)で dev/test/fixture 名 kid を拒否すれば監査の合格条件(「production public
JWKS に development
kid が出ない」「staging/review/container で危険 default を使わせない」)を満たし、かつ development/test は常に boot する。installer は jwt.rb の
`if Rails.env.local?`
下でしか走らないため、installer 側の hard-fail は回帰の元凶でしかなく**削除**する(production では installer 自体が走らず、registry が provided
ENV 鍵の dev 名 kid を拒否する)。

### 変更

- `lib/jit_security_jwt_registry.rb`
  - `enforce_public_key_hygiene?` を **`!Rails.env.local?`** に簡素化。
  - `public_deployment?` / `public_host?` / `local_keyset_exception?` /
    `PUBLIC_DEPLOYMENT_LOOPBACK_TOKENS` / `require "uri"` を削除(未使用化)。
  - `validate_record!` の予約 kid 拒否は `enforce_public_key_hygiene? && reserved_env_kid?(...)`
    のまま。
- `lib/jit_security_jwt_local_keyset_installer.rb`:
  install! 冒頭の hard-fail ブロックを削除 (`require "ipaddr"`/`require "uri"` も不要)。
- `config/environments/test.rb`: 追加した `JWT_ALLOW_LOCAL_KEYSET_FOR_PUBLIC_HOST` opt-in 行を撤回。
- テスト: `registry_test`
  から host 注入ヘルパ(`with_boot_hosts`/`*_host_family`)・`public_deployment?`/ `public_host?`
  直接テスト・opt-in テストを削除。「非 local で予約 kid 拒否」(`Rails.env.local?`
  を false スタブ)と「local では dev kid 許可」を残す。`local_keyset_installer_test`
  の public-deployment 拒否テストを削除。
- `docs/security/oidc-discovery-profile.md`: hygiene 節を `!Rails.env.local?`
  ベースに書き換え、opt-in flag の記述を削除。

### 残る保証

- production(`RAILS_ENV=production`): installer 不実行 + registry が dev 名 kid を拒否 → fail-fast。
- staging/review/container(非 local カスタム env): 同上で拒否。
- development/test: 常に boot(local 鍵生成可)。
- 未カバー: production を `RAILS_ENV=development`
  で起動する重大運用ミスのみ(コード外、別途運用是正)。
