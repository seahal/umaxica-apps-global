# OAuth Client Registry 現状把握レポート

> **本ファイルの位置づけ**: 実装計画ではなく、ユーザー指示に基づく**現状把握調査レポート**。Plan モードで唯一書き込みが許される場所として本ファイルを用いた。コード変更・migration 追加・route 変更は一切行っていない。

## Context

Acme サーフェスを唯一の IdP / Authorization Server とする一枚岩構成において、将来 **RFC 7591
(Dynamic Client Registration)** / **RFC 7592 (Registration Management)** / **CIMD**
(Client-Initiated Metadata
Dissemination 的拡張) を入れられる構造になっているか、入れるとしたらどこに境界を切るのかを判断するため、現在の OAuth
client の表現・解決・認証・検証ロジックを静的に洗い出した。

---

## 1. Summary

- **現状の client registry は単一ファイル `app/services/oidc_client_registry.rb`
  に集約された module で、12 個の RP を `build_clients`
  ハッシュリテラルで完全にハードコードしている**。DB に対応する `oauth_clients`
  テーブルは無い。secret のみ `Rails.app.creds` 経由で外出し。
- **client 解決は `OidcClientRegistry.find` / `find!` / `authenticate` / `authenticate_assertion` /
  `valid_redirect_uri?` / `valid_post_logout_redirect_uri?` の 6 API に集中している**。authorize /
  token / userinfo / revoke /
  logout の各エンドポイントはすべてこの module 経由で client を引いており、解決ポイントは事実上一箇所。
- **DCR/CIMD 拡張に備える上で今すぐ直すべき境界は無いが、リファクタが望ましい点は 3 つ**: (1)
  `build_clients` の静的ハッシュを DB-backed / 動的ソースに切り替えられるよう `ClientStore`
  抽象を抜き出す、(2) `VisitorAccount` という名前を `ClientMetadata` 相当に改名し RFC 7591
  metadata 用語に揃える、(3) `redirect_uris`/`scope`
  検証ロジックを registry から剥がして専用 validator にする。いずれも互換性を保ったまま段階的に可能。
- **今は `/register` を作るべきでない**。a) 既存 12
  RP がすべて first-party で、外部に登録窓口を開ける運用要件が無い、b)
  DB スキーマ・初期アクセストークン・admin 承認パス・metadata signature 検証など前提整備が未着手、c)
  `docs_*`/`news_*`/`help_*`
  の登録/ルーティング不整合 (§6) のような既存のクリーンアップを先にすべき。実装する段階に達したら、まず DB-backed
  registry へのリファクタを 1 PR で先に通すのが安全。

---

## 2. Evidence

### 2.1 レジストリ本体

- `app/services/oidc_client_registry.rb` (全 418 行)
  - `VisitorAccount = Data.define(...)` (14–32) — client metadata の値オブジェクト。
    `public_client?` / `confidential_client?` / `private_key_jwt_client?` を提供。
  - `find(client_id)` (43–65) — ハッシュ検索 + secret 取得 + VisitorAccount 構築。
  - `find!(client_id)` (70–72) — 未登録時 `ClientNotFound` raise。
  - `valid_redirect_uri?(client_id, uri)` (77–82) — `Array#include?` による厳密一致。
  - `valid_post_logout_redirect_uri?` (84–89) — 同上。
  - `authenticate(client_id, secret_credential)` (106–112) — secret_credential vs registry の
    `client_secret` を
    `ActiveSupport::SecurityUtils.secure_compare`。**`client_secret.blank? || secret_credential.blank?`
    の場合は false を返すため、secret 不在 confidential
    client が secret 無しで通る事故は起きない**。
  - `authenticate_assertion(client_id, assertion, token_url:)` (114–119) — `private_key_jwt`
    クライアント限定で `OidcClientAssertionJwt.valid?` に委譲。
  - `build_clients` (158–296) — 12 個の RP 定義 (sign-rp, base-rails-rp, core-next-rp, app-ios-rp,
    app-android-rp, docs_app/org/com, news_app/org/com, help_app/org/com)。
  - `metadata_auth_method(client_id)` (334–336) — **コメントで「diagnostic-only, must not be used
    for token endpoint authentication」と明記** されており、認証判定では使われていない。

### 2.2 認可リクエスト検証

- `app/services/oidc_authorize_request_validator.rb`
  - `response_type=="code"`, `code_challenge` 必須, `code_challenge_method=="S256"` 強制。
  - `validate_redirect_uri!` → `OidcClientRegistry.valid_redirect_uri?` に委譲。
  - `validate_scope_allowlist!` — 要求 scope - `client.allowed_scopes` の差集合が空でなければ
    `InvalidScope` raise。

### 2.3 トークン交換

- `app/services/oidc_token_exchange_service.rb` (全 339 行)
  - `authenticated_client?` (59–68) — 優先順位: client_assertion → public_client (secret 空のみ可) →
    `OidcClientRegistry.authenticate`。
  - `public_client_authenticated?` (70–72) — `client_secret.blank?` で true。`client.public_client?`
    は registry 側の `registered_token_endpoint_auth_method == "none"`
    でのみ true になるため、confidential client が誤って public 扱いされる経路は無い。
  - `find_code` (85–93) — Org/Com/App 各 ticket DB を順に `lock.find_by(code:)`。
  - `validate_code` (95–103) — expired/consumed/revoked + `redirect_uri` 一致 + `client_id` 一致。
  - `validate_authorized_scopes` (105–113) — **`requested_scopes.include?("openid")` を要求** — pure
    OAuth
    (openid 無し) は token 交換段階で必ず invalid_grant になる。意図的だが制約として明文化されていない。
  - `verify_pkce` (115–120) — code_verifier 必須、`authorization_code.verify_pkce` に委譲。

### 2.4 access token 認証 (userinfo)

- `app/services/oidc_access_token_authenticator.rb` の `token_belongs_to_audience?` (≈ 94 行付近) —
  token record の `oidc_client_id` から registry を引き、resource_type と payload の `aud`
  が registry の `client.aud` と一致するかを確認。

### 2.5 revoke / end-session

- `app/services/oidc_token_revocation_service.rb` — `authenticate(client_id, client_secret)`
  で認証後、token 行の `oidc_client_id` が request の `client_id` と一致するかを再確認。
- `app/services/oidc_end_session_request.rb` — `logout_request` の場合 `find(client_id)`、
  `id_token_hint` の場合は **全 `client_ids` を lazy に試行して JWT 検証が通る最初の client を選ぶ**
  という総当たり構造になっている (将来 client 数が大きく増える DCR 環境下では性能と暗号 oracle 観点で再設計が要る)。

### 2.6 RP 側設定

- `config/initializers/omniauth.rb` — 外部 IdP (Google /
  Apple) との OmniAuth 接続定義。Acme の自前 RP には関与しない。
- secret は `Rails.app.creds.option(:"OIDC_CLIENT_SECRETS_#{client_id.upcase}")` で取得 (registry の
  `resolve_secret_credential`)。Rotation パス無し。

### 2.7 トークン永続化

- `app/models/client_authorization_code.rb` — `client_id` (string 64) + `redirect_uri` +
  `code_challenge` (S256) + `code_challenge_method` (validation で `S256` のみ許可) +
  `verify_pkce(code_verifier)` (SHA256 -> base64url + secure_compare)。
- `app/models/client_token.rb` — `oidc_client_id` (string 64) + `oidc_sid` (UUID) + `oidc_jti`
  (UUID) + `oidc_scope` + `refresh_token_digest` + `dpop_jkt`。
- 同形の `OperatorAuthorizationCode` / `OperatorToken` (org_ticket DB) と `VisitorAuthorizationCode`
  / `VisitorToken` (com_ticket DB)。

### 2.8 ルーティング (host 分離)

- `config/routes/acme.rb` — `constraints host: [boot_config.fetch(:hosts).acme_service.host]`
  で app/com/org サーフェスを完全分離。各サーフェス配下に `/oauth/authorize`, `/oauth/token`,
  `/oauth/userinfo`, `/oauth/revoke`, `/oauth/jwks`, `/.well-known/openid-configuration`,
  `/oidc/logout` を持つ。
- `config/routes/sign.rb`, `config/routes/core.rb`, `config/routes/palm.rb` — RP 側 callback。
- **`/register` は存在しない (確認済)**。

---

## 3. Current Flow

### authorize request (Acme)

1. `Acme::App::Oauth::AuthorizationsController#new`
2. → `OidcAuthorizeRequestValidator.call(params:, resource:)`
   - `response_type == "code"` / `code_challenge` 必須 / `code_challenge_method == "S256"`
   - `OidcClientRegistry.find!(client_id)` で client 解決 (未登録 → ClientNotFound)
   - `valid_redirect_uri?(client_id, redirect_uri)` で厳密一致
   - `validate_scope_allowlist!` で `client.allowed_scopes` のサブセットか検証
3. → `OidcAuthorizationCodeIssuer` が `client_id` / `redirect_uri` / `code_challenge` / `scope` /
   `nonce` / `acr` / `auth_method` を保存して 302 redirect

### token request (Acme)

1. `Acme::App::Oauth::TokensController#create` → `AcmeOauthTokenEndpoint` concern
2. →
   `OidcTokenExchangeService.call(grant_type:, code:, redirect_uri:, client_id:, client_secret:, code_verifier:, client_assertion_type:, client_assertion:, dpop_proof:, token_endpoint_uri:, request_method:)`
3. → `valid_grant_type?` (= "authorization_code" のみ)
4. → `authenticated_client?`:
   - `client_assertion` 提示 → private_key_jwt 検証
   - `client.public_client?` (registered method == "none") → `client_secret.blank?` 必須
   - それ以外 → `OidcClientRegistry.authenticate` (secure_compare、両者非空が前提)
5. → `find_code` (Org/Com/App ticket DB を順に lock.find_by)
6. → `validate_code` (expired/consumed/revoked + redirect_uri 厳密 + client_id 厳密)
7. → `validate_authorized_scopes` (openid 必須 + invalid_scopes 空)
8. → `verify_pkce` (code_verifier → SHA256 → base64url → secure_compare with stored code_challenge)
9. → `validate_dpop_proof` (任意、`DpopProofValidator`)
10. → `consume_and_issue_tokens!` — code を consume、access_token (JWT) / refresh_token
    (digest 保存 + plain 返却) / id_token を発行

### refresh token request

- `OidcTokenExchangeService` の `grant_type` は `authorization_code` のみ。**refresh は
  `acme/*/edge/v0/token/refresh` の別経路**
  (本調査では構造のみ確認、ロジック未追跡)。DCR 観点では、これが独立スタックである点を
  `grant_types_supported` の宣言と合わせて確認が要る。

### RP auth start/callback

- Sign / Core / Base から `/auth/authorization` を起点に Acme `/oauth/authorize` へリダイレクト。
- Acme 側 `/auth/callback` ハンドラがコード受領 → token 交換 → セッション確立。

### logout / revoke

- `/oauth/revoke` — client 認証後、`token` 行の `oidc_client_id` を再確認して `revoke!`。
- `/oidc/logout` — `logout_request` の場合 `find(client_id)` + URL/state 検証。 `id_token_hint`
  のみの場合は **全 client_ids 総当たりで JWT 検証** という構造で client 解決。

---

## 4. Data Model Inventory

### OAuth client 自体 (DB 化されていない)

| 項目                                | 場所                                                                                     | 形式                              |
| ----------------------------------- | ---------------------------------------------------------------------------------------- | --------------------------------- |
| client_id                           | `OidcClientRegistry#build_clients` のハッシュキー                                        | string                            |
| client_secret                       | `Rails.app.creds.option(:OIDC_CLIENT_SECRETS_*)`                                         | plaintext (encrypted credentials) |
| redirect_uris                       | 同 hash の `:redirect_uris` (boot host から動的構築)                                     | Array&lt;String&gt;               |
| post_logout_redirect_uris           | 同 hash の `:post_logout_redirect_uris`                                                  | Array&lt;String&gt;               |
| backchannel_logout_uris             | 同                                                                                       | Array&lt;String&gt;               |
| backchannel_logout_session_required | 同 (default false)                                                                       | Bool                              |
| aud                                 | 同                                                                                       | String                            |
| resource_type                       | 同 (`"client"` / `"operator"` / `"visitor"`)                                             | String                            |
| name                                | 同                                                                                       | String                            |
| allowed_scopes                      | 同 (default `%w(openid profile email)`)                                                  | Array&lt;String&gt;               |
| token_endpoint_auth_method          | 同 (default 未設定 = nil)                                                                | String?                           |
| jwt_namespace                       | 同 (`"SIGN_APP"` / `"ACME_APP"` / `"CORE_APP"` / 未設定)                                 | String?                           |
| grant_types                         | **保持していない** (固定で `authorization_code` のみ)                                    | —                                 |
| response_types                      | **保持していない** (固定で `code` のみ)                                                  | —                                 |
| jwks / jwks_uri                     | **無い**。private_key_jwt クライアントは JWKS をアプリ内 `JitSecurityJwtRegistry` で管理 | —                                 |
| client_uri / logo_uri               | **無い**                                                                                 | —                                 |
| status / revoked_at / disabled_at   | **無い** (リアルタイム失効手段なし、コード変更 + 再起動が必要)                           | —                                 |
| confidential / public 区別          | `public_client?` 派生プロパティ (`registered_method == "none"`)                          | derived                           |

### トークン関連 (DB 化済み、surface 別 3 セット)

`client_authorization_codes` / `operator_authorization_codes` / `visitor_authorization_codes`:

- `code` (string 64, UNIQUE), `client_id` (string 64), `redirect_uri` (text), `code_challenge`,
  `code_challenge_method` (S256 のみ), `scope`, `nonce`, `state`, `acr`, `auth_method`, `user_id` /
  `staff_id` / `visitor_id`, 各種タイムスタンプ。

`client_tokens` / `operator_tokens` / `visitor_tokens`:

- `oidc_client_id` (string 64), `oidc_sid` (UUID UNIQUE), `oidc_jti` (UUID UNIQUE),
  `oidc_connection_id`, `oidc_scope`, `refresh_token_digest` (binary UNIQUE), `dpop_jkt`,
  `public_id` (string 21 UNIQUE), `discarded_at`, `purged_at`, status FK。

`client_oidc_connections` / `operator_oidc_connections` / `visitor_oidc_connections`:

- `client_id` (string 64), `user_id`, `scope`, `last_used_at`, `revoked_at`、 `(user_id, client_id)`
  UNIQUE。

---

## 5. Validation Inventory

| 対象                                    | 実装                                                                                                                                                                                                     | 場所                                                                                         |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| redirect_uri                            | **厳密一致** (`Array#include?`、正規化無し)                                                                                                                                                              | `OidcClientRegistry#valid_redirect_uri?` (77–82)                                             |
| redirect_uri (token 段階)               | authorization_code の保存値と request 値の `==` 比較                                                                                                                                                     | `OidcTokenExchangeService#validate_code` (99)                                                |
| scope (authorize)                       | `client.allowed_scopes` のサブセット必須、unknown は reject                                                                                                                                              | `OidcAuthorizeRequestValidator#validate_scope_allowlist!`                                    |
| scope (token)                           | 再検証 + `openid` 必須                                                                                                                                                                                   | `OidcTokenExchangeService#validate_authorized_scopes` (105–113)                              |
| grant_type                              | `"authorization_code"` のみ許可                                                                                                                                                                          | `OidcTokenExchangeService#valid_grant_type?` (55–57)                                         |
| response_type                           | `"code"` のみ許可                                                                                                                                                                                        | `OidcAuthorizeRequestValidator`                                                              |
| token_endpoint_auth_method              | client 構築時に `registered_auth_method` を保持。判定は `client.public_client?` (== "none") → public、それ以外 → confidential。**default fallback は使わない** (`metadata_auth_method` はメタデータ専用) | `OidcClientRegistry#find` (47, 61), `OidcTokenExchangeService#authenticated_client?` (59–68) |
| PKCE (authorize)                        | `code_challenge` 必須 + `code_challenge_method == "S256"` 強制                                                                                                                                           | `OidcAuthorizeRequestValidator`                                                              |
| PKCE (token)                            | `code_verifier` 必須 + SHA256(verifier) base64url を `code_challenge` と `secure_compare`                                                                                                                | `OidcTokenExchangeService#verify_pkce` (115–120), `ClientAuthorizationCode#verify_pkce`      |
| client_secret                           | Rails encrypted credentials に平文保存。比較は `ActiveSupport::SecurityUtils.secure_compare`。両者非空チェック有り (downgrade 防止)                                                                      | `OidcClientRegistry#authenticate` (106–112), `#resolve_secret_credential` (328–330)          |
| private_key_jwt                         | `OidcClientAssertionJwt.valid?` で alg / typ / aud (= token_endpoint_uri) / iss / sub / exp / iat / jti 検証                                                                                             | `app/services/oidc_client_assertion_jwt.rb`                                                  |
| jwks_uri / 動的 JWKS                    | **未実装** (アプリ内 `JitSecurityJwtRegistry` のキーセットを使用)                                                                                                                                        | —                                                                                            |
| client status / revocation              | **未実装** (registry に状態無し、無効化はコード変更が必要)                                                                                                                                               | —                                                                                            |
| HTTP Basic 認証 (`client_secret_basic`) | **未実装** (body params の `client_secret` のみ参照)                                                                                                                                                     | —                                                                                            |

---

## 6. Gaps / Risks

> 修正案は実装しない。観察された懸念のみ列挙。

### Critical

なし。secret 不在 confidential client の none 降格、wildcard redirect_uri、scope
escalation など最重要懸念は静的検査の範囲では発見されなかった。

### High

1. **`docs_*` / `news_*` / `help_*` の登録/ルーティング/secret 不整合**
   —レジストリには 9 件登録されているが、(a) `token_endpoint_auth_method`
   未設定 (= 内部判定で confidential 扱い、しかし credentials に対応 secret が存在する確証は無い)、(b) 対応する callback
   route (`/auth/callback`) が `config/routes/docs.rb` 等に見当たらない、(c) これらの surface が IdP
   RP として運用される予定があるかも不明、という三重の不整合。レジストリと実運用 client の乖離は将来 DCR を入れたとき「謎の登録済み client」が残りセキュリティ監査を曇らせる。

2. **`/oidc/logout` の `id_token_hint` 経路が全 client 総当たり JWT 検証** —
   `OidcEndSessionRequest#verified_id_token_hint` は `OidcClientRegistry.client_ids.lazy.filter_map`
   で全 client を試す。現在 12 件なら問題は無いが、DCR で client 数が増えた場合に O(n) の暗号検証が走る + 暗号 oracle の懸念。logout 時に
   `client_id` 提示を要求する設計の方が安全。

3. **client 失効/無効化の実時間手段が無い** — registry に `revoked_at` / `disabled_at`
   相当フィールド無し、トークン側にも client-wide 失効を呼ぶ口が無い。secret 漏洩時はコード変更 + 再起動以外の救済手段が無い。

### Medium

4. **`metadata_auth_method` の意図しない使用リスク** — 現状 `metadata_token_endpoint_auth_method`
   は discovery document でのみ参照される設計で、コメントにも「must not be used for token endpoint
   authentication」と明記。ただし将来うっかり `metadata_token_endpoint_auth_method`
   を認証分岐で使うと、未指定 client が `"client_secret_post"`
   にデフォルト降格する可能性がある。命名 (`metadata_...`) は良いが、`registered_token_endpoint_auth_method.nil?`
   の client がそもそも存在することの方が設計的な臭い。

5. **client_secret rotation パス無し** — registry
   secret は credentials ファイル更新 + 全インスタンス再起動でしか回せない。重複期間 (old/new 並行受理) を持てない。

6. **scope に `openid` 必須** — `OidcTokenExchangeService#validate_authorized_scopes` (110) が
   `requested_scopes.include?("openid")` を要求するため、pure OAuth
   (openid 無し) の grant が不可。設計意図 (OIDC only) なら docs/ADR に明示すべき。

7. **`build_clients` の boot 時 freeze + Concurrent::AtomicReference キャッシュ**
   —動的更新ができない構造。DCR を入れる際は cache invalidation 設計が必要。

### Low

8. **`jwt_namespace` 未設定 client (`docs_*`/`news_*`/`help_*`)** —
   token 発行時に namespace 解決が ambiguous になる可能性。実運用していない裏返しとも取れる。

9. **`response_types_supported` / `grant_types_supported` / `token_endpoint_auth_methods_supported`
   が discovery で client-by-client 表現できない** — registry は per-client な
   `grant_types`/`response_types` を保持していないため、metadata がサーバ全体で固定。RFC
   7591 の per-client metadata と整合させるには schema 拡張が要る。

10. **redirect_uri 構築側の port hard-coding (`:3000`)** — `OidcClientRegistry#build_redirect_uris`
    が `Rails.env.production?` でなく `public_host?` でも非 production を判定し `:3000`
    を付ける。複数 dev port (e.g. `:3001`) 運用がある場合に擦れる。

---

## 7. DCR / CIMD Extension Readiness

| 観点                               | 評価                    | 根拠                                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ClientRegistry 境界                | **Needs refactor**      | 解決 API は集約済み (6 メソッド) で良いが、保管が `build_clients` のハードコード literal。`ClientStore` (read interface) と `ClientRegistry` (resolution + validation) を分離し、static / DB-backed の 2 実装を切り替えられるようにすれば DCR が乗る。                                                                                                               |
| ClientMetadata 表現                | **Mostly ready**        | `VisitorAccount` Data Object に主要 metadata は揃っているが、(a) `grant_types` / `response_types` / `jwks_uri` / `client_uri` / `logo_uri` / `contacts` / `software_id` / `software_version` 不在、(b) クラス名 `VisitorAccount` が DDD 上 misleading。`ClientMetadata` への改名 + フィールド追加で対応可。                                                          |
| redirect_uri validation            | **Ready**               | 厳密一致のみ + token 段階で再確認、ワイルドカード無し。DCR で新規 client が登録する uri に対しても同 validator を再利用できる。登録時の追加 validation (https 強制 / 同一 origin / loopback 例外など) は別レイヤで足す。                                                                                                                                             |
| scope policy                       | **Ready**               | `client.allowed_scopes` のサブセット強制 + token 段階で再検証。DCR では「登録時に申請された scope のうち、AS が認可した部分集合だけが `allowed_scopes` に入る」運用にすれば既存 validator を使い回せる。                                                                                                                                                             |
| token endpoint authentication      | **Ready (with caveat)** | `client_secret_post` / `private_key_jwt` / `none` を判別可能。downgrade 防止も入っている。`client_secret_basic` 未対応 + JWKS は内蔵 registry なので、DCR でクライアント自身の `jwks_uri` を入れる場合は `OidcClientAssertionJwt` を拡張する必要あり。                                                                                                               |
| public/confidential classification | **Ready**               | `registered_token_endpoint_auth_method` 由来で判定、default fallback 無し。新規登録時に method を必須にすれば一貫性が保てる。                                                                                                                                                                                                                                        |
| registration management (RFC 7592) | **Not ready**           | `registration_client_uri` / `registration_access_token` / `registration_access_token_digest` を保管する場所が無い。RFC 7592 PUT による metadata 更新を受けるなら、registry が in-memory 不変 hash である今の前提を崩す必要がある。                                                                                                                                   |
| CIMD readiness (client_id が URL)  | **Not ready**           | (a) DB column 型は `string(64)` 固定で URL を入れると溢れる、(b) `OidcClientRegistry#find` が `client_id.to_s` をハッシュキーにする想定、(c) client_id format validation が「ハッシュキーであれば何でも良い」緩い前提、(d) 外部 metadata 取得用の cache layer と SSRF 防御が無い、(e) `jwks_uri` 解決経路が無い。CIMD は schema・cache・network 層の追加実装が必要。 |

---

## 8. Recommended Next Prompt

次に Codex / Claude に投げるべきは「**実装はしないが、`OidcClientRegistry`
を将来 DB-backed に切り替え可能にするための境界設計レポート**」。以下プロンプト案を貼り付けて使う。

```
Umaxica Rails repository の `app/services/oidc_client_registry.rb` を、将来 RFC 7591 DCR を
入れるために DB-backed registry へ置き換え可能な形にリファクタする「設計のみ」を整理してください。

制約:
- 実装しない、ファイル変更しない、migration 追加しない、テスト追加しない。
- 既存 12 RP の挙動・契約は完全に保つ前提。
- 既存呼び出し元 (authorize / token / userinfo / revoke / logout) の API は 1 つも変えない前提。

整理してほしい観点:
1. `OidcClientRegistry` を以下 3 層に分割する設計の妥当性:
   - `ClientStore` (data source 抽象、`fetch(client_id) -> raw config Hash or nil` のみ)
   - `ClientMetadata` (現 VisitorAccount 相当の値オブジェクト、改名)
   - `ClientRegistry` (resolution + secret 解決 + validation を司る、現 module 相当)
2. 既存呼び出し元の API を 1 つも変えずに上記分割を導入する移行手順
3. `StaticClientStore` (現状の build_clients ハッシュ) と将来の `ActiveRecordClientStore` の
   両実装を切り替える設定接点
4. `registered_token_endpoint_auth_method` nil 問題 (docs_*/news_*/help_* グループ) の扱い:
   登録から外すべきか、明示的に値を入れるべきか、設計上どちらが筋か
5. `id_token_hint` の全 client 総当たり問題の API 変更を伴わない緩和策
6. `client_secret` rotation を入れるなら ClientStore 層のどこで old/new 並行受理を表現するか
7. client revocation (実時間失効) を入れる場合の最小 schema 追加案 (実装はしない)
8. 上記リファクタの PR を 1 本に収めるか、分割すべきか
9. リファクタ後に DCR を入れるとしたら、`/register` controller がどの module を呼べば最小で
   登録できるか (controller のスケッチのみ、実コードは書かない)

出力形式:
- 日本語
- ファイルパス + 行番号 + クラス/メソッド名を必ず引用
- 「変更しない」境界と「変更する」境界を表で明示
- ADR ドラフトとして使える程度の粒度
```

---

## Verification (本レポートそのものの検証)

本レポートは静的調査のみで作成しているため、以下の手順で再確認可能 (実行は今回はしない):

- `app/services/oidc_client_registry.rb:106-112` の `authenticate` は両者 blank を弾く、を
  `bin/rails runner` で `OidcClientRegistry.authenticate("sign-rp", "")`
  が false を返すことで確認可能 (read-only)。
- `OidcClientRegistry.client_ids` を出力し、`config/routes/*.rb` の `host:` 制約と突き合わせて
  `docs_*` / `news_*` / `help_*` が callback route を持たない事実を確認可能。
- `bin/rails routes | grep -E "(oauth|oidc|register|\.well-known)"` で `/register`
  不在 + 既存 endpoint 一覧を確認可能。
- 既存テスト `test/services/oidc_*` (例: `test/services/oidc_issuer_test.rb`
  等) の静的読み取りで本レポートの解決経路を裏取り可能。
