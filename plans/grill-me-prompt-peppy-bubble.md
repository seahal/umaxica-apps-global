# Core Next.js + Rails Core BFF / API 境界 設計レビューと推奨

> 種別: 設計レビュー / 評価レポート（実装はまだ行わない）対象:
> Core サーフェス（`jp.umaxica.app`）と Side サーフェス（`side.jp.umaxica.app`）表記方針: 散文は日本語、コード識別子・ルート・Cookie 名・audience 名は英語。

## Context（なぜこの設計を行うか）

Umaxica の公開 Web 体験を Next.js Core（UI / SSR）+ Rails Core（browser-facing BFF /
API）で構成し、さらに Next.js の SSR/RSC が消費する非ユーザーバウンドな読み取り専用データ源として private な Side サーフェスを新設したい。本レビューの目的は、提案された routing
/ 認証 / 認可 / Cookie / CSRF /
Cloudflare 境界が、**既存の受理済み ADR・実コード・ルート語彙と整合し、安全に Rails で実装可能か**を検証し、矛盾点を洗い出して具体的な推奨に落とすこと。

提案の語彙（Acme / Sign / Core / Base / Palm）は既存の route
scope・controller と一致しており、土台は実在する。一方で提案のいくつかは受理済み ADR と矛盾するため、本プランはユーザーが選択した方針（後述）に沿って矛盾を明示しつつ実装可能な形へ整える。

### 確定した方針（ユーザー選択）

1. **ブラウザ資格情報モデル = Option 2（browser-held JWT）。** `__Host-core_access`（JWT）+ refresh
   cookie。ブラウザは Next.js backend を経由せず Rails Core に直接 `/api/v0/*` を叩く。→
   **受理済み ADR の Web Boundary / Guardrails と矛盾するため、ADR の supersede/amend が前提条件。**
2. **Side = 専用 private surface。** 新 `Side::` namespace、internal-only host、service bearer
   token のみ。既存 secret-credential lifecycle（`*SecretCredential` モデル + `sign_secret_*`
   services）を再利用。
3. **新規 Core BFF API namespace = `/api/v0`。** legacy `/web/v0`・`/edge/v0` は変更しない。
   `/auth/*`・`/sso/*` は ADR どおり `/api/v0` の外に残す。

---

## 1. 既存コードとの整合・矛盾サマリ

### 整合している点

- **語彙は実在する。** `config/routes/{acme,sign,core,palm,base}.rb` に各 scope があり、
  `app/controllers/{acme,sign,core,...}/{app,org,com}/` に surface-local `ApplicationController` /
  `BareController` が存在。Core ルートには既に `/auth/callback`・`/sso/authorize`・`/sso/logout`
  あり（`config/routes/core.rb:33-40`）。
- **JWT 検証パイプラインが既存。** `app/services/security_jwt_auth_access_token_codec.rb`
  （ES384、`verify_iss`/`verify_aud`/`required_claims`
  を強制）。audience/issuer は ENV 駆動（`app/controllers/concerns/authentication_jwt_configuration.rb`、`app/services/oidc_issuer.rb`）。
- **Bearer 抽出が既存。** `app/services/auth_authorization_header.rb`（`bearer_token` /
  `dpop_token`）。
- **Cookie 透過リフレッシュが既存。** `authentication_base.rb` の `transparent_refresh_access_token`
  と `ACCESS_COOKIE_KEY` 系。→ **Option 2 は実機構に近く、再利用できる。**
- **Refresh は opaque + digest 保存・回転・family 失効が既存。** `operator_token.rb`
  （`refresh_token_digest` / `refresh_token_generation` / `refresh_token_family_id`）。
- **Secret-credential lifecycle が production-ready。** `*SecretCredential` モデルに `lookup_digest`
  / `safe_prefix` / `scope` / `usage_policy` / 失敗回数・使用回数・失効・期限。services
  `sign_secret_{issue,verify,rotate,revoke,lookup_digest,record_event,schedule_deletion}`。→
  **Side の service
  token に必要な要件（rotation/revocation/expiry/prefix/digest/scope/audience）を全て満たす。**
- **認可は ActionPolicy（Pundit ではない）。**
  `app/policies/application_policy.rb`（default-deny）、 `has_scope?` / `jwt_scopes` /
  domain ヘルパあり。current actor は `Actor.context`。→ 提案の「ActionPolicy
  policies」は正しい。**ただし AGENTS.md は "Use
  Pundit" と記述しており、ドキュメント側がドリフトしている**（要修正の指摘）。
- **CSRF は既存。** `protect_from_forgery using: :header_or_legacy_token`（header / form 両対応）。
- **Health は再設計済み。** `BareController`
  継承・host 制約・公開は 2-state・例外クラス/メッセージ/トポロジ非開示（`notes/implementation/2026-06-13-health-endpoint-contract-redesign.md`）。

### 矛盾・要修正（重要）

| #   | 提案                                                   | 既存の受理済み決定                                                                                                                                                         | 対応                                                                                                                  |
| --- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| C1  | ブラウザが JWT を保持（`__Host-core_access`）          | `adr/acme-sign-core-base-port-boundary.md:66,187`「ブラウザは bearer token を直接保持してはならない」「JS に bearer を持たせない」。`__Host-core_sid` 不透明セッションのみ | **ユーザーが Option 2 を選択。前提として当該 ADR の Web Boundary/Guardrails を supersede する新 ADR を必須化**（§14） |
| C2  | `__Host-core_refresh` を refresh endpoint に Path 制限 | `__Host-` prefix は **Path=/ を強制し Path 制限不可**                                                                                                                      | Path 制限したい refresh は **`__Secure-` prefix** を使う（§6）                                                        |
| C3  | `/settings → Rails Core`                               | ADR:37「Base が settings/preferences/account を所有」                                                                                                                      | **settings は Base 所有**。Core host 直下に置かず Base host、または Cloudflare で `/settings → Base origin`（§4）     |
| C4  | host `jp.umaxica.app`                                  | config は `www.jp.umaxica.app`（`CORE_SERVICE_URL` / `CORE_APP` issuer origin）、ADR 例は `jp.example.com`                                                                 | **canonical host を確定する未決事項**（§15）                                                                          |
| C5  | `/api/v0/*` が現状存在                                 | 現状は `/web/v0`・`/edge/v0`。`/api/v0` は方向決定のみで未実装（`adr/api-route-vocabulary-consolidation.md`）                                                              | 新規 Core BFF は `/api/v0` を greenfield 採用、legacy は不変（Q3 確定）                                               |
| C6  | audience `palm-api`                                    | ADR:123 は `port-api`、active plan で Port→Palm 改名                                                                                                                       | **audience 名を一つに確定**（§7、§15）                                                                                |
| C7  | `Side` サーフェス                                      | 既存に Side なし。Base（Resource Server）/ Help・Docs・News（`edge/v0/entries`）あり                                                                                       | **専用 Side surface 新設**（Q2 確定、§4・§5）                                                                         |
| C8  | SameSite=Strict（暗黙に全 cookie）                     | OIDC callback / email-link 用に `__Host-core_sid` は Lax 必須（ADR:76）                                                                                                    | **OIDC transaction cookie は Lax 必須**。session 系は Strict 可（§6）                                                 |

---

## 2. 直接的な批判（grill）

- **「JWT を HttpOnly cookie に入れれば JS が持たないから ADR 違反でない」は不正確。**
  ADR:66 は「ブラウザが _直接_ bearer を保持してはならない」と広く禁じており、HttpOnly
  cookie の JWT も「ブラウザが保持する bearer」に該当する。Option
  2 を採るなら**回避ではなく明示的な ADR 改定で正面突破**する必要がある。
- **`__Host-` + Path 制限は両立しない（C2）。** 提案の「`__Host-core_refresh` を refresh
  endpoint に Path 制限」は prefix 規約上不可能。Path 制限を取るなら host-only の*強制*を諦め
  `__Secure-` にする、という明確なトレードオフがある。
- **Option 2 は browser-facing refresh endpoint を必須化する。** server-side
  session を持たないため、access 失効時にブラウザが `/api/v0/token/refresh` を叩く必要がある（Option
  1 なら不要だった）。これは追加の攻撃面であり、refresh の回転/replay 検知（既存
  `refresh_token_family_id`）を確実に効かせる前提。
- **`/settings → Rails Core` は ADR の責務分割に反する（C3）。**
  settings は Base。Core に置くと Core/Base の責務境界が崩れる。
- **audience を transport に束縛しないと "confused deputy" を招く。** cookie 用 `core-browser`
  トークンが `Authorization: Bearer` でも通る／native の `port-api`
  が cookie でも通る、という状態は危険。 **transport ↔ aud バインドを検証層で強制すべき**（§8）。
- **CSRF を SameSite に依存しすぎない。** Strict は defense-in-depth だが単独で十分ではない。masked
  token を必ず併用。
- **public host に `/health` が露出している（`config/routes/core.rb:10-15`）。**
  BareController で host 制約のみのため、Cloudflare でブロックしないと公開される。

---

## 3. 推奨ルートテーブル

### `jp.umaxica.app`（Core / host = `CORE_SERVICE_URL`、org=`CORE_STAFF_URL`、com=`CORE_CORPORATE_URL`）

Cloudflare origin 振り分け:

```text
/_next/*                      -> Next.js Core
/api/v0/*                     -> Rails Core (BFF API)        [新規 namespace]
/auth/*                       -> Rails Core                   [既存 /auth/callback を拡張]
/sso/*                        -> Rails Core                   [既存 /sso/authorize, /sso/logout]
/settings, /settings/*        -> Base origin                  [ADR: settings は Base。C3]
/health, /health/*            -> Rails Core だが Cloudflare で公開ブロック（内部プローブのみ）
/*                            -> Next.js Core
```

Rails Core `/api/v0`（新規、3 surface に展開）:

```text
GET  /api/v0/session          -> 認証状態 + csrf_token のブートストラップ
POST /api/v0/token/refresh    -> refresh（__Secure-core_refresh を読む。Acme /token へ proxy）
GET  /api/v0/...              -> リソース読み取り（scope + ActionPolicy）
POST/PATCH/DELETE /api/v0/... -> 変更系（CSRF 必須、scope + ActionPolicy）
```

auth ceremony（`/api/v0` の外に維持）:

```text
GET  /auth/start              -> Acme /authorize へ（PKCE+state を __Host-core_oidc に格納）  [新規 or /sso/authorize を流用]
GET  /auth/callback           -> code を Acme /token で交換し cookie を発行                    [既存]
POST /sso/logout              -> サインアウト（cookie 破棄 + Acme refresh 失効）               [既存]
```

### `side.jp.umaxica.app`（Side / host = `SIDE_SERVICE_URL` ほか）

```text
/api/v0/*  -> Rails Side（read-only、service bearer token のみ、user cookie 拒否）
```

ルール: 外部ユーザー到達不可 / user cookie 受領禁止 / user access・refresh
token 不使用 / 変更系ルートを定義しない（read-only を routing で担保）。

### Cloudflare が担保 vs Rails が担保

- **Cloudflare**: host routing、Side と `/health` の公開ブロック、Side への inbound `Cookie`
  ヘッダ除去、WAF / rate-limit、TLS、(任意) Side への mTLS / Access。
- **Rails**: `constraints host:` による host 固定（既存パターン）、Side で user
  cookie 検出時は拒否（多層防御）、service
  bearer 必須・scope/aud 検証、Side に変更系ルートを置かない。

---

## 4. 推奨 Rails namespace / controller 構造

- **Core BFF API**: `config/routes/core.rb` の各 surface scope 内に
  `namespace :api { namespace :v0 { ... } }` を追加。controller は
  `Core::App::Api::V0::*Controller`。JSON 専用の API 基底
  `Core::App::Api::V0::ApiController`（surface `ApplicationController` を継承し、JSON 描画・CSRF
  header 戦略・集中エラーレンダラ・`require_scope!` を備える）を導入。`/auth`・`/sso`
  は既存 controller を流用・拡張。
- **Side**: 新規 `config/routes/side.rb`（`scope module: :side` +
  `constraints host: [ENV["SIDE_SERVICE_URL"], ...]`）。 `Side::App::ApplicationController` は
  **user 認証パイプラインを持たない**（`BareController` 寄り）。代わりに
  `before_action :authenticate_service!`（service bearer +
  secret-credential 検証）と read-only ガードを持つ。service token 検証は `sign_secret_verify.rb`
  相当のロジックを **Side 用に再利用/一般化**（`*SecretCredential` の
  `lookup_digest`/`safe_prefix`/`scope`/audience を使用）。
- **settings は Base**（C3）。Core には settings controller を置かない。

---

## 5. 推奨 Cookie 名 / 属性 / Path（Option 2）

| Cookie                  | 中身                                                                 | Secure | HttpOnly | SameSite | Domain         | Path                    | prefix 備考                                              |
| ----------------------- | -------------------------------------------------------------------- | ------ | -------- | -------- | -------------- | ----------------------- | -------------------------------------------------------- |
| `__Host-core_access`    | Acme 発行 JWT access token（`aud=core-browser`）。短 TTL（~10分）    | ✓      | ✓        | Strict   | なし           | `/`                     | `__Host-` は Path=/ 強制                                 |
| `__Secure-core_refresh` | **opaque** refresh handle（JWT ではない）                            | ✓      | ✓        | Strict   | なし(属性省略) | `/api/v0/token/refresh` | Path 制限のため `__Host-` 不可。`__Secure-` を採用（C2） |
| `__Host-core_oidc`      | OIDC transaction（state / PKCE verifier / nonce）。callback 後に削除 | ✓      | ✓        | **Lax**  | なし           | `/`                     | cross-site callback で送出されるため **Lax 必須**（C8）  |

ポイント:

- refresh の Path 制限を取るために `__Secure-core_refresh`
  を選択（host-only の*強制*は失うが Domain 属性は省略して実質 host-only を維持）。host-only の強制を優先するなら
  `__Host-core_refresh`（Path=/）に切替可 ― トレードオフを明記。
- access/refresh の OIDC ceremony cookie（`__Host-core_oidc`）だけは
  **Lax**。これを Strict にすると callback で state が戻らず認証が壊れる（C8）。
- JWT はブラウザ JS に渡さない（HttpOnly）。CSRF token のみ JS に渡す（§9）。

---

## 6. 推奨 token audience / scope 分割

- **`core-browser`**: cookie transport の access token（`__Host-core_access`）。Rails Core `/api/v0`
  が消費。
- **`palm-api`（または既存 `port-api`）**: native bearer、`Authorization`
  header のみ。**名称を一つに確定**（C6）。
- **`side-service`**: 当面 **JWT ではなく opaque service credential**（`*SecretCredential`
  の scope/audience カラムで表現）。将来 JWT 化するなら `aud=side-service`。
- **`base-api` / `core-api`**: Core server → Base
  server 間の server-side 呼び出し（settings 等で必要時）。ADR:125-126 準拠。

**transport ↔ aud バインド規則（必須）**: `aud=core-browser` のトークンは **cookie 経由のみ受理**、
`aud=palm-api` は **header 経由のみ受理**。逆 transport は拒否。検証層（§8）で強制。

**scope 語彙（初期は最小）**: `openid profile:read`（+ 必要に応じ
`self:read`）。settings 関連 scope は Base が消費。最終認可は scope（粗いゲート）+
ActionPolicy（current actor / ownership / tenant・org 境界）。scope チェックは API 境界の
`require_scope!`（before_action）、細粒度は policy 内（既存 `has_scope?` を再利用）。

---

## 7. 推奨 token transport unification

検証コアは `SecurityJwtAuthAccessTokenCodec` に集約済み。その手前に **transport アダプタ層**を置く:

- bearer 抽出: 既存 `AuthAuthorizationHeader#access_token`（Palm）。
- cookie 抽出: 新規 `__Host-core_access` リーダ（Core）。既存 `transparent_refresh_access_token`
  機構を Core 用に流用。
- 各アダプタが **expected aud と transport**
  を codec に渡し、§6 のバインド規則を強制（cookie→`core-browser`、header→`palm-api`）。

これで「検証は共通・抽出と aud は transport 別」を満たす。

---

## 8. 推奨 CSRF パターン

- 既存 `protect_from_forgery using: :header_or_legacy_token` を API 基底に適用（masked token）。
- ブートストラップ `GET /api/v0/session` が `{ "authenticated": bool, "csrf_token": "..." }`
  を返す（`form_authenticity_token`）。Next.js/ブラウザはメモリ保持し、unsafe メソッドで
  `X-CSRF-Token` 送出。
- SameSite=Strict は defense-in-depth であり**単独で頼らない**。CSRF
  token は資格情報ではないので JS 露出可。JWT は露出不可。

---

## 9. 推奨 JSON エラー契約

提案形状を採用しつつ observability 境界（例外クラス/メッセージ/トポロジ非開示）を強制:

```json
{
  "error": {
    "code": "authentication_required",
    "message": "...",
    "detail": null,
    "request_id": "req_...",
    "fields": null
  }
}
```

- `code`: 安定・クライアントが分岐に使用。`message`: server-side
  I18n の既定文（client は code で再マップ可）。
- `detail`: 内部情報を**絶対に漏らさない**（`notes/.../health-endpoint-contract-redesign.md`
  の no-leak 規則に整合）。
- `request_id`: **常に含める**（相関）。`fields`: validation 時のみ `{field => [messages]}`。
- 既存の汎用エラー契約は無いので greenfield。中央集約レンダラ（concern）で Rails
  validation を本形状へマップ、 `rescue_from` で配線。codes は提案どおり + `service_unavailable`
  を追加検討。

---

## 10. サインアウト

- 既存パターン再利用: Core `/sso/logout`（既存）。`logout_all_sessions_for!`（security audit
  note 由来）を流用。
- cookie 破棄: `__Host-core_access` / `__Secure-core_refresh` / `__Host-core_oidc` を削除。
- refresh 失効: Acme `/oauth/revoke`（既存）で refresh を revoke し、既存 `refresh_token_family_id`
  family を失効。
- OIDC front-channel/back-channel logout（Acme `/oidc/logout`
  既存）は**今回は遅延**。ローカル cookie 破棄 + Acme refresh 失効を先行。

---

## 11. Health / Status 境界

- 現状維持（`BareController`・host 制約・公開 2-state・no-leak）。**公開 host での `/health`
  は Cloudflare でブロック**し内部プローブのみ。
- 公開ユーザーは Rails `/health` ではなく**統一された人間可読 status
  page**（別系統）。`jp.umaxica.app/health` は公開しない。
- 可能なら health を内部 host/path へ寄せることも検討（現状は公開 Core
  host 上にあるため Cloudflare 依存）。

---

## 12. Next.js 境界

提案の allow/forbid は妥当。隠れた漏洩経路と対策:

- ブラウザは Rails に直接 `/api/v0` を叩くため、**Next.js SSR/RSC は user
  cookie を Rails へ転送しない**設計が自然。
- Next.js → Side の fetch は **`credentials: 'omit'`**、service token のみ。user-bound
  SSR を行わない。
- Cloudflare が Side への `Cookie` を除去（多層）。Next.js は `__Host-core_*`
  を読まない/設定しない。RSC payload にトークンを埋めない。

---

## 13. ログイン / callback / refresh 語彙の確定

- 全 RP 共通: `/auth/callback`（Acme/Sign/Core で既に一致）。
- 開始: `/auth/start`（新規）または既存 `/sso/authorize` を流用 ― **どちらか一方に統一**（推奨:
  `/auth/start`、`/sso/*` は SSO 系に温存）。
- refresh: **`/api/v0/token/refresh`**（Option 2 では API 操作。`/auth/refresh` ではない）。
- sign-out: `/sso/logout`（既存）。

---

## 14. 前提条件: ADR 改定（Option 2 のため必須）

実装着手前に、以下を行う（AGENTS.md「ADR と矛盾する実装は事前に conflict を明示」準拠）:

- 新 ADR を作成し `adr/acme-sign-core-base-port-boundary.md` の **Web Boundary** と **Guardrails**
  （「browser が bearer を直接保持しない」「JS に bearer を持たせない」「`__Host-core_sid`
  のみ」）を **supersede /
  amend**。決定理由と緩和策（HttpOnly・短 TTL・aud↔transport バインド・refresh の Path 制限・CSRF）を明記。
- `docs/architecture/acme-sign-core-base-port.md` の Core cookie 契約（現 `__Host-core_sid` /
  SameSite=Lax）を更新。

> これを行わない限り Option 2 の実装はリポジトリ統治に違反する。

---

## 15. リスク / 未決事項

- **(必須) ADR supersession**（§14）。未了だと governance 違反。
- **`__Host-` と Path 制限の非両立**（C2）。refresh を `__Secure-` にするか host-only 強制を取るか。
- **canonical host**: `jp.umaxica.app` か `www.jp.umaxica.app` か（C4。config は `www.jp.`）。
- **audience 名**: `palm-api` か `port-api` か（C6）。
- **settings 所有**: Base（C3）。Core host 直下に出すなら Cloudflare で Base origin へ path-route。
- **OIDC transaction cookie は Lax 必須**（C8）。
- **aud↔transport バインドの実装正しさ**（confused deputy 防止）。
- **Acme が Core RP 向けに `aud=core-browser` access + opaque refresh を発行**できる前提の確認。
- **`/api/v0` は Core だけ先行**し他 surface は `/web,/edge` のまま ― 移行までの語彙乖離。
- **Side service token の運用**（発行・回転頻度・所有者・rotation 自動化）。
- **AGENTS.md の "Use Pundit" 記述**が実体（ActionPolicy）とドリフト ― 別途修正。

---

## 16. 最小実装プラン（実装はまだ行わない）

0. **Governance**: Option 2 用の supersede ADR + cookie 契約ドキュメント更新（§14）。
1. **Core BFF API skeleton**: `config/routes/core.rb` に `namespace :api { namespace :v0 }` を 3
   surface 追加。 `Core::*::Api::V0::ApiController` 基底（JSON・CSRF
   header 戦略・集中エラーレンダラ・`require_scope!`）。
   `GET /api/v0/session`、`POST /api/v0/token/refresh`。
2. **Cookie 層**: `__Host-core_access`(JWT) / `__Secure-core_refresh`(opaque) /
   `__Host-core_oidc`(Lax) の writer/reader。検証は `SecurityJwtAuthAccessTokenCodec` 再利用 +
   cookie extractor + `aud=core-browser` + transport バインドガード。既存 `authentication_base.rb`
   の透過リフレッシュを Core endpoint へ適応。
3. **Auth flow**: `/auth/start`→Acme `/authorize`（PKCE+state を `__Host-core_oidc`）、
   `/auth/callback` で code 交換 → cookie 発行（既存 `core/.../auth/callbacks` 流用）。
4. **CSRF**: API 基底に header 戦略適用、`/api/v0/session` が `csrf_token` 返却（§9）。
5. **エラー契約**: 中央レンダラ concern（code/message/detail/request_id/fields）+ Rails
   validation マッピング + no-leak。`rescue_from` 配線。
6. **認可**: `require_scope!` + ActionPolicy policies、最小 scope 語彙。
7. **Side surface**:
   `config/routes/side.rb`（host 制約）、`Side::*::ApplicationController`（user 認証なし・service
   bearer）、`*SecretCredential` + secret lifecycle を service
   token に再利用、read-only、cookie 拒否。
8. **サインアウト**: `/sso/logout` で Core cookie 破棄 + Acme `/oauth/revoke` + family 失効。
9. **Cloudflare（Rails 外）**: path routing、`/health`・Side の公開ブロック、Side への Cookie 除去。
10. **テスト**（§17）。

---

## 17. 検証（テスト方法）

- `bin/rails test` で新規 controller/service テスト。
  - integration:
    `/auth/start → /auth/callback（cookie 発行）→ /api/v0/session → /api/v0/token/refresh → /sso/logout`
    の一巡。
  - request test で
    **cookie フラグ**（Secure/HttpOnly/SameSite/Path/prefix）をレスポンスヘッダ検証。
  - **aud↔transport 拒否**: `aud=core-browser` を header で送ると拒否、`aud=palm-api`
    を cookie で送ると拒否。
  - **CSRF**: unsafe メソッドで `X-CSRF-Token` 欠如時に `csrf_verification_failed`。
  - **scope ゲート**: 不足 scope で `authorization_denied`。
  - **Side**: service token なしで拒否、user
    cookie 付与でも拒否、verify/rotate/revoke が機能（secret lifecycle テスト）。
  - **エラー契約**: 形状一致 + `detail` に内部情報が漏れないこと + `request_id` 常在。
- JS 側に変更が及ぶ場合は Vitest（`pnpm test`）でも CSRF/fetch 経路を検証。
- narrowest test を先に、その後 surface 横断の broader test。実行できないテストは明記。
