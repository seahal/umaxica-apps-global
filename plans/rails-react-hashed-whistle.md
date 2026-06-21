# アーキテクチャレビュー: routing / configuration / OAuth・OIDC entry point の統合

> 種別: 評価レポート（厳格レビュー）。リポジトリ規約上、確定後は
> `memos/2026-06-14-auth-config-architecture-review.md`
> 等の日付付き flat ファイルへ移すのが本来の置き場。plan モードの制約で一旦ここに記載する。

## Context

この変更の動機は、認証・認可・OAuth/OIDC の entry point と設定値が `acme/sign/core/base/palm`
という上位 namespace × `app/com/org` というサーフェスの二軸で機械的に複製され、設定値の読み取り口が
`app/` と `lib/`
に散乱している点にある。「動いているから正しい」を排し、保守性・セキュリティ・変更容易性の観点で、設定の読み取り口と OAuth/OIDC
entry point を集約し、不要・重複を削減することが目的。

**重要な前提補正**: 依頼文は `app/com`・`app/com/org`
というディレクトリを前提にしているが、**それらは実在しない**。実構造は次の二層である。

- 第1層（上位 namespace = サービス / BFF サーフェス）: `acme` `sign` `core` `base` `palm` `help`
  `docs` `news`（`app/controllers/<service>/...`）
- 第2層（アクター・ブランドサーフェス）: `app`(=client) `com`(=visitor/corporate)
  `org`(=operator/staff)（`app/controllers/<service>/{app,com,org}/...`）

つまり「`com` ドメイン」は上位 namespace ではなく、各サービス配下に毎回現れる第2層である。`app/com`
直下に何かが置かれているのではなく、`com` が `acme/com`, `sign/com`, `core/com`,
... と8系統に複製されている。レビューはこの実構造に合わせて行う。

---

## 1. Executive summary

### 一番まずい設計上の問題 5 個

1. **設定値の読み取り口が完全に分散している（最重要）。** `app/` と `lib/` の中に
   `ENV.fetch("ACME_*_URL"/"SIGN_*_URL"/"ID_*_URL"/"CORE_*_URL")` の直接参照が
   **118 箇所**。controller・concern・service object が ENV を直読みしており、依頼の方針「controller
   / service
   object から ENV や credentials を直接読ませない」に真っ向から違反している。読み取り口が 1〜2 箇所どころか百単位。
   - 検出:
     `rg -n 'ENV\.fetch\("(ACME|SIGN|ID|CORE)_[A-Z]*_URL"|ENV\["(ACME|SIGN|ID|CORE)_[A-Z]*_URL"\]' app/ lib/`

2. **同一概念のホストが 2 系統の名前で並走している。** `ID_SERVICE_URL` / `ID_CORPORATE_URL` /
   `ID_STAFF_URL` と `SIGN_SERVICE_URL` / `SIGN_CORPORATE_URL` / `SIGN_STAFF_URL` は
   **同じ Sign(=id) サービスの host**。`config/application.rb` で両方が同じ既定値（`id.umaxica.app`
   等）に設定され、`app/controllers/concerns/authentication_client.rb:73` は
   `%w(SIGN_SERVICE_URL ID_SERVICE_URL).filter_map`
   で**両方を相互フォールバック**している。これは典型的な命名ゆれであり、どちらが正かが決まっていない。

3. **OIDC issuer / endpoint host が 3 系統に三重ハードコードされている。**
   - `app/services/oidc_issuer.rb`（`ENV["ACME_*_URL"]` から OP endpoint を組む）
   - `app/services/oidc_client_registry.rb`（`build_redirect_uris` が `ENV["*_SERVICE_URL"]`
     から redirect_uri を組む）
   - `app/services/identity_*_ceremony_contract.rb` **8 ファイル**（`SIGN_ISSUERS` / `ACME_ISSUERS`
     の host を `https://id.umaxica.app` 等で直書き）issuer URL は OIDC の対外契約（`iss`
     クレーム）であり、3 箇所がずれた瞬間に token 検証が壊れる。単一の真実源が無い。

4. **OAuth/OIDC entry point が「サービス×サーフェス」で機械複製されている。**
   `/.well-known/jwks.json` は `acme` `sign` `core` の 3 サービス × `app/com/org`
   で定義。`/sso/authorize` `/sso/logout` は `acme` と `core` の両方。`/auth/callback` は `acme`
   `sign` `core` 全てに存在。route 定義のレベルで同じ entry point が何重にも現れ、controller も
   `acme/{app,com,org}/oauth/...`
   のように 3 複製されている。新サービス追加時にこれらが線形に増殖する。

5. **`OidcClientRegistry` のクライアント定義に一貫性が無く、dead client の疑いがある。** `sign_*`
   `acme_*` `core_*` は `token_endpoint_auth_method: "private_key_jwt"` と `jwt_namespace`
   を持つが、`docs_*` `news_*`
   `help_*`（9 クライアント）は**両方とも欠落**。実際に OIDC フローを通っているのか、見栄えで足された placeholder なのかが判別できない。

### 今すぐ消せそうなもの（詳細は §5）

- `palm/app/oauth/callbacks_controller.rb` と `oauth/callback/ios`・`oauth/callback/android`
  route（静的レスポンスのスタブ疑い。要 1 回の挙動確認）。
- `OidcClientRegistry` の `docs_*` / `news_*` / `help_*` クライアント（auth
  method 欠落、RP フロー未接続の疑い）。
- `ID_*_URL` 3 変数（`SIGN_*_URL` に一本化）。

### 慎重に扱うべきもの（削除前に影響範囲明示が必須）

- `/.well-known/jwks.json` の `core`・`sign`
  側（自サービスが署名する token の検証鍵を配っている可能性。OP の鍵配布と RP の自鍵配布を混同して消すと token 検証が即死する）。
- `/sso/*` の `acme` と `core` の重複（どちらが SSO 起点かを確定するまで削除不可）。
- `oidc_issuer.rb` の host 解決（`iss`
  クレームに直結。値を変えると既存 token・discovery キャッシュが壊れる。`[[feedback-csp-report-url-immutable]]`
  と同じく対外契約として不変に扱う）。

---

## 2. 現状の routing map

### 2.1 トップレベル

`config/routes.rb` は 8 本の `draw` のみ:

```ruby
draw :acme   # Global BFF + OAuth/OIDC Authorization Server (OP)
draw :sign   # Sign up/in。OIDC Relying Party + OmniAuth(social)
draw :core   # Regional app(JP)。token refresh / SSO / JWKS
draw :base   # control-plane(health/robots/sitemap)
draw :palm   # native bearer-token API(app のみ)
draw :help / :docs / :news  # 公開・読み取り専用コンテンツ
```

各 route ファイルは `scope module: :<service>` → `constraints host: ENV[...]` →
`scope module: :<surface>`
の入れ子で、`app/com/org`（acme は +`net`/`dev`）ごとにブロックを**そのまま複製**している。host 制約はすべて ENV 直書きのインライン制約で、専用 Constraint クラスは無い。

### 2.2 auth / oauth / oidc 関連 route（サービス別）

| entry point      | path                                                          | controller#action                  | 提供サービス         | 種別           | OP/RP           |
| ---------------- | ------------------------------------------------------------- | ---------------------------------- | -------------------- | -------------- | --------------- |
| discovery        | `GET /.well-known/openid-configuration`                       | `openid_configurations#show`       | acme                 | public         | OP              |
| jwks             | `GET /.well-known/jwks.json`                                  | `jwks#show`                        | **acme・sign・core** | public         | OP/自鍵         |
| authorize        | `GET /oauth/authorize`                                        | `oauth/authorizations#show`        | acme                 | public         | OP              |
| token            | `POST /oauth/token`                                           | `oauth/tokens#create`              | acme                 | public         | OP              |
| userinfo         | `GET /oauth/userinfo`                                         | `oauth/user_info#show`             | acme                 | public(bearer) | OP              |
| revoke           | `POST /oauth/revoke`                                          | `oauth/revocations#create`         | acme                 | public         | OP              |
| jwks(oauth)      | `GET /oauth/jwks.json`                                        | `oauth/jwks#show`                  | acme                 | public         | OP              |
| sso authorize    | `GET /sso/authorize`                                          | `sso/authorizations#show`          | **acme・core**       | internal       | RP起点          |
| sso logout       | `POST /sso/logout`                                            | `sso/logouts#create`               | **acme・core**       | internal       | -               |
| oidc logout      | `GET /oidc/logout`                                            | `oidc/logouts#show`                | acme                 | public         | OP(end_session) |
| rp callback      | `GET /auth/callback`                                          | `auth/callbacks#show`              | **acme・sign・core** | public         | RP              |
| omniauth(google) | `GET /social/google/callback`                                 | `auth/omniauth_callbacks#omniauth` | sign(app のみ)       | public         | RP(social)      |
| omniauth(apple)  | `GET/POST /social/apple/callback`                             | `auth/omniauth_callbacks#omniauth` | sign(app のみ)       | public         | RP(social)      |
| omniauth failure | `GET /auth/failure`                                           | `auth/omniauth_callbacks#failure`  | sign(app のみ)       | public         | RP(social)      |
| native oauth cb  | `GET /oauth/callback{,/ios,/android}`                         | `oauth/callbacks#show`             | palm(app のみ)       | public         | RP? スタブ疑い  |
| token refresh    | `POST /api/v0/token/refresh`                                  | `api/v0/tokens#refresh`            | core                 | internal       | -               |
| session          | `GET /api/v0/session`                                         | `api/v0/sessions#show`             | core                 | internal       | -               |
| edge token       | `GET /edge/v0/token/check`,`POST .../dbsc`,`POST .../refresh` | `edge/v0/token/*`                  | acme・sign           | internal       | -               |

### 2.3 domain（surface）ごとの差分

- **OmniAuth(social) は `sign/app` のみ**。`com`/`org`
  には無い（社外ソーシャルログインは client サーフェス限定）。`COM_GOOGLE_*` / `ORG_GOOGLE_*`
  の ENV フラグは存在するが route が無く、**設定と route の対応が破綻**している（§3 違反）。
- **edge token**: `acme` は check/dbsc/refresh の 3 つ、`sign`
  は check/dbsc の 2 つ（refresh 欠落）。サービス間で粒度がずれている。
- `core` のみ `api/v0/token/refresh` と `api/v0/session` を持つ。token refresh が `acme(edge)` と
  `core(api/v0)` の 2 方式で並走。

### 2.4 重複している entry point（要集約）

1. `jwks.json` … acme / sign / core（+ acme は `/oauth/jwks.json` も）→ **最大 4 経路**
2. `/auth/callback` … acme / sign / core × app/com/org
3. `/sso/authorize` `/sso/logout` … acme / core
4. token refresh … acme `/edge/v0/token/refresh` と core `/api/v0/token/refresh`

---

## 3. Configuration / settings inventory

### 3.1 設定値の入口一覧（抜粋・重要度順）

| 種別              | ファイル                            | key                                                                                                   | 使用箇所                          | domain    | 削除可能性      | 集約先候補                   | コメント                                          |
| ----------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------- | --------- | --------------- | ---------------------------- | ------------------------------------------------- |
| ENV               | 各所(118)                           | `ACME_*_URL` `SIGN_*_URL` `ID_*_URL` `CORE_*_URL`                                                     | controller/concern/service 直読み | 全        | medium          | `SurfaceHosts` 単一 resolver | 直読みを禁止し resolver 経由に                    |
| ENV(既定値)       | `config/application.rb:120-128`     | `ID_*_URL` と `SIGN_*_URL`                                                                            | 既定値定義                        | sign      | **high(ID系)**  | `SIGN_*_URL` に一本化        | 同概念二重命名                                    |
| service(hardcode) | `oidc_issuer.rb:45-54`              | ACME host→issuer                                                                                      | OP endpoint 全生成                | acme      | low(集約先)     | issuer 単一源                | `iss` 契約。可変厳禁                              |
| service(hardcode) | `oidc_client_registry.rb:126-260`   | clients 18件                                                                                          | OIDC client 全解決                | 全        | low(集約先)     | client 単一源                | docs/news/help は不整合                           |
| service(hardcode) | `identity_*_ceremony_contract.rb`×8 | `SIGN_ISSUERS`/`ACME_ISSUERS`                                                                         | ceremony token 発行/検証          | sign+acme | **medium**      | `oidc_issuer.rb` 参照に置換  | issuer 三重定義の 3 つ目                          |
| ENV               | `config/initializers/webauthn.rb`   | `WEBAUTHN_{APP,COM,ORG}_{RP_ID,ORIGIN}` + 共有 `WEBAUTHN_RP_ID`/`ORIGIN` + `TRUSTED_ORIGINS`          | WebAuthn 起動検証                 | 全        | low             | surface 設定オブジェクト     | surface 別と共有 fallback が混在                  |
| credentials       | `config/initializers/omniauth.rb`   | `OMNI_AUTH_{GOOGLE_APP,APPLE_*}`                                                                      | OmniAuth provider                 | sign/app  | low             | keep                         | initializer に domain 知識集中                    |
| credentials       | `oidc_client_registry.rb:295`       | `OIDC_CLIENT_SECRETS_<ID>`                                                                            | client secret 解決                | 全        | low             | keep(registry 内)            | 唯一まともに集約済み                              |
| ENV(flag)         | env 各所                            | `COM_GOOGLE_SIGNUP_ENABLED` `ORG_GOOGLE_*`                                                            | (route 不在)                      | com/org   | **high**        | 削除候補                     | 対応 route 無し=死にフラグ疑い                    |
| ENV               | env 各所                            | `JUMP_GATEWAY_URL` `JUMP_GATEWAY_JWKS_URL` `JUMP_RT_TTL_SECONDS` `JUMP_RETURN_*` `JUMP_ALLOWED_HOSTS` | jump サービス連携                 | cross     | low             | `JumpConfig` 集約            | 5+ 変数が散在                                     |
| ENV(flag)         | service                             | `RISK_ENFORCEMENT_DISABLED` と `RISK_ENFORCEMENT_ENABLED`                                             | risk 判定                         | cross     | medium          | 1 フラグへ                   | enable/disable 両建ては危険                       |
| Settings obj      | `app/models/actor/configuration.rb` | method_missing 委譲                                                                                   | ほぼ未使用                        | actor     | medium(unknown) | 用途確定 or 削除             | `Actor::Configuration`/`Actor::SignConfiguration` |

### 3.2 重複・命名ゆれ（同一概念の多重名）

| 概念                     | 並走している名前                                                                                                                     | 判定                                               |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| Sign(id) サービスの host | `ID_SERVICE_URL` ↔ `SIGN_SERVICE_URL`（com/org も同様）                                                                              | **同一概念**。相互 fallback 実装あり。一本化すべき |
| OP issuer host           | `oidc_issuer.host_for_resource_type` ↔ `OidcClientRegistry.build_redirect_uris` ↔ ceremony contract の `ACME_ISSUERS`/`SIGN_ISSUERS` | **同一概念の三重定義**                             |
| jwks 公開鍵              | `/.well-known/jwks.json`(acme/sign/core) と acme `/oauth/jwks.json`                                                                  | OP 鍵と自鍵で**別概念の可能性**。要切り分け        |
| token refresh            | acme `edge/v0/token/refresh` ↔ core `api/v0/token/refresh`                                                                           | 別実装・同目的。要統合判断                         |
| risk 有効化              | `RISK_ENFORCEMENT_ENABLED` ↔ `RISK_ENFORCEMENT_DISABLED`                                                                             | 同一概念の二重否定。1 つに                         |

### 3.3 domain boundary 違反

- **service object / controller が ENV を直読み**（118 箇所）。例:
  `acme/app/social/authentications_controller.rb` が `ENV.fetch("ID_SERVICE_URL", ...)`
  を 9 回。これは「設定が共通層にある」のではなく「設定が末端に漏れている」逆方向の漏洩。
- **initializer に domain 知識**: `config/initializers/omniauth.rb` が Google/Apple provider・host
  allowlist・surface guard を内包。
- **`config/application.rb` が全サービスの host 既定値を一手に持つ**（30+ の `*_URL`
  既定値）。共通層（application.rb）に全ドメインの設定が集中する典型違反。`org` 固有 host も
  `app`/`com` と同じ場所に並んでいる。

---

## 4. Namespace critique

### 4.1 各 namespace の責務推定（証拠付き）

| namespace            | 実体                                            | 推定責務                                  | 評価                                                          |
| -------------------- | ----------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------- |
| `acme`               | OAuth/OIDC OP 一式 + BFF。`app/com/org/net/dev` | プロダクトの中核 BFF 兼 **OIDC Provider** | 名前はブランド名（acme=社内コードネーム）。責務は明確だが肥大 |
| `sign`               | sign up/in、OmniAuth、`/auth/callback`          | **認証専用サービス / OIDC RP**            | 機能層の名前。妥当                                            |
| `core`               | 地域(JP)アプリ、token refresh、SSO、jwks        | 地域版アプリ                              | acme との責務境界が曖昧（SSO/jwks/refresh が両方にある）      |
| `base`               | health/robots/sitemap                           | control-plane                             | 薄い。dumping ground化はしていない。妥当                      |
| `palm`               | native API(app のみ)、oauth callback スタブ     | bearer-token API                          | ほぼ空。dead 疑い                                             |
| `help`/`docs`/`news` | 公開コンテンツ                                  | コンテンツ配信                            | 妥当だが OIDC client だけ registry に居座る                   |

**`app`/`com`/`org`（第2層）** はアクター種別（client / visitor(corporate) / operator(staff)）。DB
tier（`*_principal`/`*_ticket`/`*_zenith`）や authn/authz
concern（`AuthenticationClient`/`Visitor`/`Operator`）と 1:1 対応しており、ここは一貫している。`[[project-ddd-sns-domain-alignment]]`
の Zenith canonical と整合。

### 4.2 責務の混線

- **OIDC Provider 責務が `acme` に集中する一方、`jwks` と `sso` が `core`/`sign`
  にも漏れている**。「OP は acme」という境界が route レベルで破れている。
- **`core` と `acme` の境界が曖昧**。`core`=地域アプリなら OP
  endpoint（jwks/sso）を持つ理由が不明。地域別 OP として独立しているのか、acme の OP を借りるべき RP なのかが、コードからは判別不能（要確認だが、`core_*`
  が `OidcClientRegistry` に **client** として登録されている事実から、`core`
  は RP であるべきで、自前 jwks/sso は過剰の疑いが濃い）。
- **`base` は健全**（control-plane に徹している）。`BareController` 契約（`ActionController::Base`
  直接継承）も AGENTS.md と整合。

### 4.3 統一案 / rename・move 候補

- namespace の意味軸を文書化（`acme/sign/core/...`=**サービス層**、`app/com/org`=**アクターサーフェス**）。`adr/`
  に 1 本書く。
- OP 責務を `acme` に一元化し、`core`/`sign`
  の jwks/sso は「自鍵配布」か「OP 重複」かを判定の上、後者なら削除（§5）。
- `acme`（OP）と
  `palm`（API）は名前がブランド/コードネームで責務が読めない。最低限コメント／ADR で「acme=OIDC OP +
  BFF」「palm=native bearer
  API」を固定する。**rename は対外 host 名（ACME\_\*\_URL 等）と結合しているため見送り**（`[[feedback-csp-report-url-immutable]]`
  と同様、対外契約を見栄えで変えない）。

---

## 5. 削除・統合候補リスト

| 対象                                                                              | 種別(file/route/ctrl) | 分類                            | 理由                                                                      | リスク                                                     | 推奨アクション                                                                |
| --------------------------------------------------------------------------------- | --------------------- | ------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `palm/app/oauth/callbacks_controller.rb` + `oauth/callback{,/ios,/android}` route | file+route            | **likely delete**               | 静的レスポンスのスタブ疑い。palm は app のみで他に実体が薄い              | native アプリの OAuth 戻り先に実使用なら認証断             | 挙動を 1 回確認→未使用なら削除。使用中なら acme OP の `/auth/callback` へ統合 |
| `OidcClientRegistry` の `docs_*`/`news_*`/`help_*`（9件）                         | config                | **likely delete / consolidate** | `token_endpoint_auth_method` と `jwt_namespace` 欠落。RP フロー未接続疑い | これらサーフェスが実際に OIDC ログインしている場合は認証断 | 各サーフェスの `/auth/callback` 実呼び出しを確認→未使用なら削除               |
| `ID_SERVICE_URL`/`ID_CORPORATE_URL`/`ID_STAFF_URL`                                | settings              | **consolidate**                 | `SIGN_*_URL` と同一概念・相互 fallback                                    | env 設定済みデプロイがある場合、片方削除で host 解決失敗   | `SIGN_*_URL` に一本化。`ID_*` は移行期間 deprecated alias→撤去                |
| `COM_GOOGLE_*` `ORG_GOOGLE_*` ENV フラグ                                          | settings              | **safe→likely delete**          | 対応する social route が `sign/app` のみで com/org に無い                 | 将来 com/org social を入れる予定があるなら時期尚早         | route 不在を確認の上、死にフラグとして削除                                    |
| `RISK_ENFORCEMENT_DISABLED`                                                       | settings              | **consolidate**                 | `RISK_ENFORCEMENT_ENABLED` と二重否定                                     | 本番で無効化に依存している場合は挙動変化                   | 単一フラグ（既定 enabled）へ                                                  |
| `/.well-known/jwks.json`(core, sign)                                              | route                 | **keep / 要切り分け**           | OP 鍵配布なら acme に集約可。自鍵配布なら必要                             | **誤削除で token 署名検証が全断**                          | 各サービスが何の鍵を配るか確定するまで keep                                   |
| `/sso/*`(core or acme の一方)                                                     | route                 | **consolidate**                 | SSO 起点が 2 箇所                                                         | logout/SSO flow 断                                         | 起点を 1 つに確定後、他方を削除                                               |
| token refresh(acme edge vs core api/v0)                                           | route+ctrl            | **consolidate**                 | 同目的 2 実装                                                             | refresh 断でセッション維持不能                             | 片方を正とし統合。移行まで両建て維持                                          |
| `Actor::Configuration` / `Actor::SignConfiguration`                               | file                  | **unknown→確認**                | ほぼ未使用                                                                | 低                                                         | 参照 0 を確認→削除、用途あれば集約先として活用                                |

検出コマンド例:

```bash
# palm callback の実使用
rg -n 'oauth_callback|ios_callback|android_callback|palm.*oauth' app/ config/ test/
# docs/news/help client が RP として呼ばれているか
rg -n 'docs_(app|com|org)|news_(app|com|org)|help_(app|com|org)' app/ test/
# 死にフラグ
rg -n 'COM_GOOGLE_|ORG_GOOGLE_' app/ config/ test/
# jwks を出すコントローラが配る鍵の namespace
rg -n 'class .*JwksController|JitSecurityJwtRegistry|jwt_namespace' app/controllers app/services
```

---

## 6. 推奨する最終構造

設定の読み取り口を集約し、OAuth/OIDC の真実源を 1 つにする。ディレクトリは現状の二層（service ×
surface）を維持しつつ、**設定アクセスを resolver/registry に閉じる**。

```
config/
  application.rb            # host 既定値の巨大ブロックは撤去 →
  settings/
    surface_hosts.yml       # ★全 *_URL の単一定義(env 名と既定値)。唯一の host 真実源
  initializers/
    omniauth.rb             # provider 定義のみ。host/guard は SurfaceHosts 参照に
    oidc.rb                 # (新規) OidcEndpoints/Registry の起動時 freeze・検証

app/
  services/
    surface_hosts.rb        # ★ENV を読む唯一の入口。SurfaceHosts.url(:sign, :app) 等
    oidc/                   # ★散在 oidc_*.rb をこの名前空間へ集約(既に空 dir あり)
      issuer.rb             #   旧 oidc_issuer.rb。host は SurfaceHosts 経由
      client_registry.rb    #   旧 oidc_client_registry.rb。redirect_uri も SurfaceHosts 経由
      endpoints.rb          #   authorize/token/userinfo/jwks/logout の単一定義
    identity/
      *_ceremony_contract.rb # SIGN_ISSUERS/ACME_ISSUERS を撤去し Oidc::Issuer 参照
  controllers/
    <service=acme|sign|core|base|palm|help|docs|news>/
      <surface=app|com|org>/
        ...                 # ENV 直読み禁止。SurfaceHosts/Oidc::* 経由のみ
    concerns/
      authentication_*.rb   # host 解決は SurfaceHosts に委譲(直読み撤去)
```

### configuration の置き場（明示）

- **host/URL**: `config/settings/surface_hosts.yml` ＋ 読み取りは `app/services/surface_hosts.rb`
  のみ。他の一切のファイルから `ENV[*_URL]` 直読みを禁止。
- **OIDC client / issuer / endpoint**: `app/services/oidc/`
  配下の registry・issuer・endpoints の 3 オブジェクトのみが真実源。ceremony
  contract はそこを**参照するだけ**。
- **secret**: credentials（`OIDC_CLIENT_SECRETS_*`, `OMNI_AUTH_*`）は registry / omniauth
  initializer 内でのみ解決。
- **surface 別 WebAuthn/cookie**: `app/services/`
  の surface 設定オブジェクトへ（initializer は検証のみ）。

### `app` と `com`/`org` 境界の明示

- 第2層の `org`(operator) 固有設定（`*_STAFF_URL`, `ORG_*` フラグ, `WEBAUTHN_ORG_*`）は
  `SurfaceHosts`/surface 設定オブジェクト内で **`org` キー配下に閉じる**。`app`/`com` と同じ平場に
  `ORG_*` を並べない。
- 依頼の「`app/com`
  直下に configuration を置かない」は、実構造では「`config/application.rb`（共通層）に全サーフェス host を直書きしない」に読み替えて適用する。

---

## 7. 実施順序

- **Step 1: 安全な棚卸し（read-only）** §5 の検出コマンドで palm callback / docs・news・help client
  / `COM/ORG_GOOGLE_*` フラグ / `Actor::Configuration` の実参照を確定。`notes/implementation/`
  に棚卸し結果を残す。
- **Step 2: settings 読み取り口の統合** `SurfaceHosts`(yml +
  service) を新設。`config/application.rb` の host 既定値を yml へ移送。`ID_*_URL` を `SIGN_*_URL`
  の deprecated alias 化。118 箇所の `ENV[*_URL]` 直読みを `SurfaceHosts`
  経由へ機械置換（サービス×サーフェス単位で段階的に）。
- **Step 3: OAuth/OIDC entry point の統合** `app/services/oidc/` へ `oidc_*.rb` を移動。issuer
  host を `Oidc::Issuer` 一本に。ceremony contract 8 ファイルの `SIGN_ISSUERS`/`ACME_ISSUERS` を
  `Oidc::Issuer` 参照へ置換（**`iss` 値は一字も変えない**回帰テスト付き）。`OidcClientRegistry`
  の docs/news/help を確定結果に従い削除 or 整備。
- **Step 4: routes の整理** jwks の真実源を確定し core/sign の重複を削除 or 自鍵用と明示。`/sso/*`
  を 1 起点へ。token refresh を acme/core どちらかへ寄せる。social の死にフラグと不在 route を解消。
- **Step 5: dead code 削除** palm oauth callback スタブ、未使用 client、死にフラグを撤去。
- **Step 6: テスト追加（§8）** 各統合点に回帰ガードを敷いてから撤去を確定。

各 Step は独立 PR。Step 3/4 は security-sensitive なので、撤去前に Step 6 の回帰テストを先行させる。

---

## 8. 必要なテスト

- **routing spec**: `/.well-known/openid-configuration` `/.well-known/jwks.json`
  `/oauth/{authorize,token,userinfo,revoke}` `/oidc/logout` `/sso/{authorize,logout}`
  `/auth/callback`
  が各 service×surface で期待 controller に解決すること（統合前後で差分が無いこと）。
- **request spec (OP)**: authorize→token→userinfo→revoke の正常系。`iss`/`aud`/`jwks` が
  `Oidc::Issuer`/`Registry` の値と一致（host 集約後も値不変を assert）。
- **auth callback flow**: sign/app の OmniAuth(Google/Apple) callback、acme/sign/core の
  `/auth/callback` 正常系 + invalid `state` / invalid `nonce` / provider error の各失敗系。
- **logout flow**: `/oidc/logout`(end_session) と `/sso/logout` の正常系・セッション破棄確認。
- **missing configuration**: `SurfaceHosts` で必須 env 欠落時に**起動時に loud fail**（silent
  fallback 禁止、AGENTS.md 準拠）。`webauthn.rb` の `TRUSTED_ORIGINS` 欠落検証も維持。
- **multi-domain behavior**:
  app/com/org それぞれの host 制約で正しい surface に解決し、サーフェス越えしないこと（cross-surface 漏れの回帰ガード）。
- **settings 単一源**: `rg 'ENV\[.*_URL'` が `app/`・`lib/`
  で 0 件になることを CI で検査するガードテスト（`SurfaceHosts` と allowlist 以外を禁止）。
- **issuer 不変**: ceremony contract 改修前後で各 `iss` 文字列が完全一致する snapshot テスト。

JS 側（React Router /
Hono）でログイン・callback 遷移に関与する箇所があれば Vitest で対応（`vp test`）。

---

## 9. 厳しめの指摘

- **将来どこが壊れるか**: issuer host が `oidc_issuer.rb` / `oidc_client_registry.rb` / ceremony
  contract ×8 の **3 系統に分散**している。誰かが片方だけ host を更新した瞬間、`iss`
  不一致で token 検証が全面崩壊する。これは「いつか」ではなく「次に誰かが host を触ったとき」起きる。
- **新 domain 追加時の増殖**: いま `news`
  を 1 つ足すだけで、route ブロック（app/com/org 分）、`OidcClientRegistry`
  の 3 エントリ、`SurfaceHosts` 相当の `*_URL` 6 変数、host allowlist（production.rb /
  development.rb / CSP / omniauth
  guard）が芋づる式に増える。設定の入口が散っている限り、サービス追加コストが O(散在箇所数) で線形増加する。
- **いま削らないと負債化する箇所**: ① `ID_*_URL` と `SIGN_*_URL`
  の二重命名（相互 fallback が「とりあえず動く」を作り、誰も正を決められなくなる）。②
  `OidcClientRegistry` の docs/news/help（auth
  method 欠落のまま放置されると「使われているか分からない OIDC
  client」が増殖し、セキュリティ棚卸し不能になる）。③ `RISK_ENFORCEMENT_ENABLED`/`DISABLED`
  の二重否定フラグ。
- **「名前がそれっぽいだけで責務が曖昧」な箇所**:
  - `core` … 「地域アプリ」なのに OP 的な jwks/sso/token
    refresh を持つ。RP なのか OP なのかが名前からも route からも確定できない。最大の境界曖昧点。
  - `palm` … bearer API を名乗るが中身は oauth
    callback スタブほぼ単独。名前が責務を約束しているのに実体が無い。
  - `acme` … ブランド名で「OP +
    BFF」という二責務を吸い込んでいる。肥大の温床（`authentication_base.rb`
    が ~95KB 単一 concern という別の dumping ground もここに紐づく）。
  - `Actor::Configuration` … 「設定」を名乗るが method_missing 委譲のみでほぼ未使用。名前だけの器。

---

## 検証方法（このレビュー後の実装フェーズ向け）

1. `rg -c 'ENV\[.*_URL\]\|ENV\.fetch\("[A-Z_]*_URL"' app/ lib/` … Step
   2 完了時に 0 へ漸減することを定点観測。
2. `bin/rails routes | rg 'oauth|oidc|jwks|sso|auth/callback|openid-config'` … Step 4 前後で entry
   point 差分を目視。
3. `bin/rails test test/integration` の auth/oidc 系 + 追加した routing/issuer-snapshot テスト。
4. 各 Step PR で `bin/rails test` の該当範囲を最小から実行し、security-sensitive な Step
   3/4 は撤去前に Step 6 のガードが緑であることを必須条件にする。
