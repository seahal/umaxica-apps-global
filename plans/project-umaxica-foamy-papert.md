# Acme Surface 設計レビュー：設計意図の復元

> 調査日: 2026-06-26  
> 対象: identity / preference / account / avatar / organization / organization unit / sign 境界

---

## 1. 発見した関連ファイル

### ADR・設計意思決定（高重要度）

| パス                                                 | 種別 | 関連領域                       | 重要度     | 理由                                                          |
| ---------------------------------------------------- | ---- | ------------------------------ | ---------- | ------------------------------------------------------------- |
| `adr/identity-authority-boundary.md`                 | ADR  | identity / session / sign 境界 | **high**   | Acme=IdP・Sign=Credential Gateway の根拠                      |
| `adr/acme-session-and-token-authority.md`            | ADR  | identity / session             | **high**   | Acme がセッション・トークン権威を持つ根拠                     |
| `adr/sign-credential-gateway-surface.md`             | ADR  | sign                           | **high**   | Sign に残すべきもの（credential ceremony のみ）の根拠         |
| `adr/sign-residual-idp-surface-retirement.md`        | ADR  | sign / acme 境界               | **high**   | Sign IdP 機能の Acme 統合、移行の明示リスト                   |
| `adr/preference-soft-bubble-doctrine.md`             | ADR  | preference                     | **high**   | preference を surface ごとに独立 DB で管理する根拠            |
| `adr/collective-hierarchy-model.md`                  | ADR  | organization / org unit        | **high**   | Collective 再帰階層、parent_id の不変性の根拠                 |
| `adr/account-workspace-avatar-billing.md`            | ADR  | account / avatar / org         | **high**   | Account→Membership→Workspace→AvatarGrant→Avatar の構造        |
| `adr/surface-account-collective-model-naming.md`     | ADR  | account / org                  | **high**   | Persona/Enterprise/Agent/Bureau/Individual/Company の命名根拠 |
| `adr/app-actor-client-naming.md`                     | ADR  | identity                       | **high**   | App actor = Client（旧 User）命名の根拠                       |
| `adr/org-actor-operator-naming.md`                   | ADR  | identity                       | **high**   | Org actor = Operator（旧 Staff）命名の根拠                    |
| `adr/com-actor-visitor-naming.md`                    | ADR  | identity                       | **high**   | Com actor = Visitor（旧 Customer）命名の根拠                  |
| `adr/actor-current-facade.md`                        | ADR  | identity / preference          | **high**   | Actor facade が唯一のリクエストコンテキスト API               |
| `adr/identifier-hmac-emergency-rotation.md`          | ADR  | identity（email/tel）          | **medium** | email/telephone の HMAC ダイジェスト保管の設計                |
| `adr/setting-preference-remove-polymorphic-owner.md` | ADR  | preference                     | **medium** | 撤回済み：polymorphic owner は実装されていない                |

### ドキュメント（高重要度）

| パス                                                      | 種別 | 関連領域             | 重要度     | 理由                                                                |
| --------------------------------------------------------- | ---- | -------------------- | ---------- | ------------------------------------------------------------------- |
| `docs/architecture/acme-sign-core-base-port.md`           | doc  | 全体構成             | **high**   | Acme=IdP / Sign=RP / Core=BFF の採択コンポーネントモデル            |
| `docs/architecture/sign-settings-to-acme-identity.md`     | doc  | sign / identity      | **high**   | Sign /settings から Acme /identity への移行範囲の明示               |
| `docs/architecture/preference.md`                         | doc  | preference           | **high**   | preference JWT 読み取り専用フロー、request-local overlay の設計     |
| `docs/architecture/database-boundaries.md`                | doc  | 全体構成             | **high**   | surface×role の多 DB 構成（principal/ticket/zenith/signal/setting） |
| `docs/architecture/actor-naming.md`                       | doc  | identity             | **medium** | surface actor・JWT actor claim の命名ルール                         |
| `docs/dictionary/identity-account-organization-avatar.md` | doc  | 全領域               | **high**   | Identity/Account/Organization/Avatar の DDD 定義                    |
| `docs/security/session-token-authority.md`                | doc  | identity / sign 境界 | **high**   | Acme がセッション権威を持つ詳細仕様                                 |
| `docs/security/preference-settings-authority.md`          | doc  | preference           | **high**   | preference 書き込みは Sign preference surfaces のみ                 |
| `docs/security/observability-boundary.md`                 | doc  | logging              | **medium** | ログ境界定義                                                        |

### ルート・コントローラ（高重要度）

| パス                                                     | 種別       | 関連領域       | 重要度     | 理由                                                  |
| -------------------------------------------------------- | ---------- | -------------- | ---------- | ----------------------------------------------------- |
| `config/routes/acme.rb`                                  | route      | 全領域         | **high**   | Acme の現在のルート構造（singular/plural の現状）     |
| `config/routes/sign.rb`                                  | route      | sign           | **high**   | Sign に残っているルート                               |
| `app/controllers/acme/app/identity/`                     | controller | identity       | **high**   | 新規追加された Identity 配下コントローラ群            |
| `app/controllers/acme/app/application_controller.rb`     | controller | 基底           | **high**   | Acme App 全体の認証・認可パイプライン                 |
| `app/controllers/acme/app/pre_access_controller.rb`      | controller | identity       | **high**   | authenticate_client! のみの中間基底                   |
| `app/controllers/acme/app/full_access_controller.rb`     | controller | account/avatar | **high**   | require_selected_actor_context! 付き基底              |
| `app/controllers/sign/app/settings_controller.rb`        | controller | sign           | **high**   | Acme へリダイレクトするだけの Sign settings 残骸      |
| `app/controllers/sign/app/settings/emails_controller.rb` | controller | sign           | **medium** | index は Acme へリダイレクト、update/destroy は :gone |

### モデル・関心事（高重要度）

| パス                                       | 種別               | 関連領域     | 重要度   | 理由                                                             |
| ------------------------------------------ | ------------------ | ------------ | -------- | ---------------------------------------------------------------- |
| `app/models/concerns/identity.rb`          | model concern      | identity     | **high** | ClientIdentity/OperatorIdentity/VisitorIdentity の共通ロジック   |
| `app/models/concerns/account.rb`           | model concern      | account      | **high** | Persona/Agent/Individual が include する Account concern         |
| `app/models/concerns/public_id.rb`         | model concern      | public ID    | **high** | NanoID-21 生成・不変性ガード                                     |
| `app/models/client_identity.rb`            | model              | identity     | **high** | IdP/RP identity binding（issuer/subject/audience 複合 unique）   |
| `app/models/client_account.rb`             | model              | account      | **high** | RP account binding（ClientAccount は Account concern と別物）    |
| `app/models/avatar.rb`                     | model              | avatar       | **high** | public_id / owner_organization_id / representing_organization_id |
| `app/models/organization.rb`               | model              | organization | **high** | domain が unique 識別子（public_id ではない）                    |
| `app/models/actor/preference.rb`           | model value object | preference   | **high** | Value Object（immutable、永続化なし）                            |
| `app/policies/client_withdrawal_policy.rb` | policy             | identity     | **high** | ClientPolicy（operator管理）と分離された自己削除ポリシー         |

### アクティブな実装プラン（重要度）

| パス                                                      | 種別 | 重要度   | 理由                                      |
| --------------------------------------------------------- | ---- | -------- | ----------------------------------------- |
| `plans/active/acme-sign-core-base-port-implementation.md` | plan | **high** | コンポーネント分割の現在進行中プラン      |
| `plans/backlog/sign-acme-boundary-remediation.md`         | plan | **high** | Sign 側残留コードの Acme 移行のバックログ |

---

## 2. 現在のモデル構造の復元

### 主要概念の対応表

| 概念                 | 実装モデル名                                                                                      | 単数/複数 resource                                                        | public ID 参照                                          | 主な関連                                                                                                            | 設計意図の推定                                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **Identity**         | `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`                                         | **singular**（current context）                                           | あり（public_id）だが外部 URL 参照はしない              | belongs_to source_record; has_one Persona/Agent/Individual                                                          | OIDC IdP/RP binding record。(issuer, subject, audience) 複合 unique。認証主体の証明書であり、SNS 上の表示主体ではない |
| **Account**          | `Persona`（app） / `Agent`（org） / `Individual`（com）                                           | **plural**（他 account を列挙する文脈） / **singular**（current context） | あり（Account concern が PublicId を include）          | belongs_to Client/Operator/Visitor; has_many Memberships                                                            | 利用主体。Session→Account→Membership→Workspace の起点。display name や組織帰属を持つ                                  |
| **Preference**       | `actor/preference.rb` Value Object; `ClientPreference` / `AppPreference` 等 concrete              | **singular**（current user の設定）                                       | なし（内部 ID のみ）                                    | surface-specific setting DB / principal DB に分離                                                                   | Soft Bubble Doctrine: surface 横断統合を意図的に回避。JWT から読み取り専用、写き込みは Sign preference surface のみ   |
| **Avatar**           | `Avatar`                                                                                          | **plural**                                                                | あり（public_id）                                       | owner_organization_id / representing_organization_id; has_many AvatarMemberships / AvatarOwnershipPeriods / Handles | App/Org のみ存在（Com 不可）。SNS 上の表示人格。Account が operate、Organization が own という分離設計                |
| **Organization**     | `Enterprise`（app） / `Bureau`（org） / `Company`（com）                                          | **plural**                                                                | あり（**domain** が unique 識別子、public_id ではない） | has_many Divisions / Departments; parent_id（階層）                                                                 | Collective 階層の実装。billing・契約・Avatar 所有の主体。parent_id は不変（closure table 的）                         |
| **OrganizationUnit** | `EnterpriseUnit` / `BureauUnit` / `CompanyUnit`                                                   | **plural**                                                                | 調査では明確な確認なし（要追加調査）                    | parent_id による再帰階層（Collective concern）                                                                      | 階層ノード。委譲・転送設計の痕跡あり（avatar_ownership_periods / avatar_memberships パターンが示唆）                  |
| **RP/IdP Binding**   | `ClientAccount` / `VisitorAccount` / `OperatorAccount`                                            | singular（1 identity に 1 account）                                       | あり（public_id）                                       | belongs_to Client/Visitor/Operator（user_id FK）                                                                    | **Account concern（Persona等）とは別物**。OIDC RP の account binding record。混同注意                                 |
| **Sign 系モデル**    | `ClientEmail` / `ClientTelephone` / ClientPasskey / ClientTotpCredential / ClientSecretCredential | identity 配下 plural                                                      | あり（public_id で ACME identity controllers が検索）   | belongs_to Client                                                                                                   | Credential inventory。Sign 側でも参照されるが、管理 UI は Acme/identity/ に移動済み                                   |

---

## 3. Identity の設計意図

### 基本構造

```
Client (app actor) ─────────────────────────────────────┐
  │                                                      │
  ├── ClientIdentity (OIDC IdP/RP binding)              │
  │     issuer / subject / audience (composite unique)  │
  │     last_authenticated_at                           │
  │     has_one :persona ────────────────────────────── │
  │                                                      │
  └── Persona (Account concern を include)              │
        public_id, moniker                              │
        has_many :memberships                           │
        └── Membership → Enterprise (Collective)        │
```

### identity は account を持つ設計か

**Yes、間接的に**。`ClientIdentity` が `has_one :persona` を持つ。ただし：

- `ClientIdentity` は「OIDC 認証の証明書」（issuer/subject/audience の binding）
- `Persona` は「サービス利用の主体」（表示名・組織帰属・Avatar 操作権を持つ）
- 両者は 1:1 だが意図的に分離されており、Identity が Account の「所有者」ではなく「発行元」

### sign から移されたもの（ADR 明示）

`adr/sign-residual-idp-surface-retirement.md` と
`docs/architecture/sign-settings-to-acme-identity.md` が明確に定義：

| 移行済み                              | 移行先                                          |
| ------------------------------------- | ----------------------------------------------- |
| 電話番号登録                          | `Acme /identity/telephones`                     |
| withdrawal（アカウント削除）          | `Acme /identity/withdrawal`                     |
| email/telephone 設定の書き込み        | `Acme /identity/emails`, `/identity/telephones` |
| session 一覧・個別 revoke             | `Acme /identity/sessions`                       |
| recovery secret 表示                  | `Acme /identity/recovery_secrets`               |
| MFA level 設定                        | `Acme /identity/mfa`                            |
| secret credential 管理                | `Acme /identity/secrets`                        |
| OIDC /authorize, /token, /userinfo 等 | Acme（Sign の residual IdP 機能を廃止）         |
| refresh token rotation                | Acme                                            |
| session-mutating sign-out             | Acme                                            |
| step-up freshness コミット            | Acme                                            |

### sign に残されたもの（例外・理由あり）

| 残すもの                                | 理由                                                                   |
| --------------------------------------- | ---------------------------------------------------------------------- |
| WebAuthn/passkey ceremony 実行          | **WebAuthn RP ID は `id.example.com` の URL に binding**。URL 変更不可 |
| TOTP 検証 ceremony 実行                 | 同上（ceremony 実行の文脈で TOTP も Sign に残す）                      |
| Google/Apple OAuth コールバック         | 同上（コールバック URL が Sign の domain に binding）                  |
| ceremony state（短命）                  | ceremony 実行に必要な一時状態のみ                                      |
| ceremony audit record                   | ceremony の証跡                                                        |
| `/.well-known/jwks.json`（Sign 署名鍵） | Jump redirect-gateway (RT) トークン用署名鍵（OIDC id-token ではない）  |
| promotional email unsubscribe           | Public、token-verified な unsubscribe（Sign preference surface）       |

### Acme と Sign の境界の原則

> Sign は「ceremony を実行して signed result を返す」だけ。  
> Acme は「grant を発行し、result を消費して、account/session/freshness/token の変更をコミット」する。

### identity を singular resource として扱うのが自然か

**Yes**。根拠：

1. `docs/architecture/sign-settings-to-acme-identity.md` が「Sign /settings → Acme
   /identity」と singular で定義
2. `config/routes/acme.rb` に `resource :identity`（singular）が既に存在
3. "current user の identity" という概念は唯一性を持ち、plural で列挙する主体がない
4. 新規追加 `acme/app/identity/` コントローラ群が `Acme::App::Identity::BaseController`
   の下に集約されており、singular resource の構造を踏んでいる

---

## 4. Preference の設計意図

### Soft Bubble Doctrine（`adr/preference-soft-bubble-doctrine.md`）

```
app surface: AppPreference (app_setting DB) ←→ ClientPreference (app_principal DB)
org surface: OrgPreference (org_setting DB) ←→ OperatorPreference (org_principal DB)
com surface: ComPreference (com_setting DB) ←→ VisitorPreference (com_principal DB)
```

- **surface 横断統合は意図的に回避**。DB も分離されている
- preference は session-side（AppPreference 等）と actor-side（ClientPreference 等）の 2 系統
- request-local overlay（`lx`, `ct`, `tz` 等）は DB/JWT に書かない一時的な上書きのみ

### preference は誰に属するか

- **Actor（Client/Operator/Visitor）に属する**が、surface ごとに実装が分かれる
- `actor/preference.rb` が共通 Value Object（immutable）として読み取り API を提供
- `Actor.preferences.language` のように読む（Actor facade 経由）

### signed-in / signed-out の扱い

- signed-in: preference JWT（`*_preference_access`）から `Actor.preferences` を hydrate
- signed-out（Bearer のみ等）: `Actor::Preference::NULL` にフォールバック
- region（`ri`）は**必須**。欠けたリクエストはリダイレクト

### Acme preference と product preference の混在リスク

- 現状、Acme は preference の**読み取り専用**コンシューマ（Acme/Jump は書かない）
- **書き込みは Sign preference surfaces のみ**（`docs/security/preference-settings-authority.md`）
- product domain（SNS の投稿設定等）が preference に混入している痕跡は今回の調査では見当たらない

### preference を singular resource として扱うのが自然か

**Yes**。根拠：

1. `config/routes/acme.rb` に `resource :preference`（singular + nested sub-resources）が既に存在
2. "current user の preference" は唯一性を持つ
3. Soft Bubble
   Doctrine により surface ごとに独立しており、cross-surface 統合による plural 化は設計に反する

---

## 5. Account / Organization / Avatar の resource 設計

### 現在のルート構造（`config/routes/acme.rb` より）

```ruby
# App surface
resources :accounts     # plural, :id = public_id
resources :avatars      # plural, :id = public_id
resources :organizations, param: :id do   # plural, :id = public_id (or domain?)
  resources :memberships
end
resource :account       # singular（current context）
resource :organization  # singular（current context）
```

### public_id / external identifier の設計

| モデル                              | 外部参照 identifier                 | URL 使用                         | 変更可否                              |
| ----------------------------------- | ----------------------------------- | -------------------------------- | ------------------------------------- |
| Avatar                              | `public_id`（NanoID-21）            | `config/routes/acme.rb` :id      | 不変（PublicId concern で更新ガード） |
| Account（Persona 等）               | `public_id`（NanoID-21）            | `config/routes/acme.rb` :id      | 不変                                  |
| Organization（Enterprise 等）       | **`domain`**（unique string）       | 調査では domain が unique 識別子 | domain は変更可の可能性あり           |
| Handle（Avatar の user-visible ID） | `handle`（@付き表示、DB は @ なし） | SNS プロフィール URL など        | 変更可（history-tracked）             |

**注意**: Organization は `public_id` ではなく `domain`
を unique 識別子として使っている（`app/models/organization.rb`）。plural resources として
`param: :public_id` に揃える場合は、Organization モデルに `public_id` を付与するか、`domain`
を param に使うか判断が必要。

### SNS product domain と Acme control plane のどちらに寄っているか

- **Avatar**: SNS 側（follow/block/mute/post は SNS
  domain）だが、Acme が「operate 権の管理」と「ownership 管理」を担う。SNS
  product の feed/post 機能は Acme に飲み込まない
- **Account**: Acme control plane（membership、avatar 操作権限、billing の起点）
- **Organization**: Acme control plane（hierarchy、billing、contract の主体）

### plural resources 設計への衝突点

1. **Organization に public_id がない（domain が識別子）** — `param: :public_id`
   に統一するには Organization モデルへの `public_id` 付与が必要
2. **ClientAccount と Account（Persona）の混同リスク** — `ClientAccount`（RP
   binding）を "account" と呼ぶと概念が衝突する。URL 上は Persona が "account"
3. **Avatar は Com では存在しない** — `acme.com.*` の routes に `resources :avatars` を置けない
4. **Handle を avatar の "slug" 相当として使うか** — `@handle` が user-visible だが、URL の `param`
   に何を使うかは設計判断が必要

---

## 6. Organization Unit の設計意図

### 発見した痕跡

`adr/collective-hierarchy-model.md`：

- `Collective` は**再帰的な階層概念**（「Workspace」「Organization」ではなくコード上の
  `Collective`）
- 階層ノード：`EnterpriseUnit` / `BureauUnit` / `CompanyUnit`（closure table 的、`parent_id`
  は**不変**）
- 全 Account は何らかの Collective に placement される設計
- solo/unaffiliated account には「personal Collective」が生成される

`adr/account-workspace-avatar-billing.md`：

```
Session → Account → Membership → Workspace → child Workspace
                                      |
                                      v
                                AvatarGrant → Avatar
```

- `AvatarGrant`：Avatar の操作権限の配布（owner でなくても operate 可能）
- `avatar_ownership_periods`（starts_at/ends_at）：Avatar **所有権**の時間的追跡
- `avatar_memberships`（validity dates）：Account が Avatar を operate していた期間の記録

`app/models/avatar.rb`：

- `owner_organization_id`（string で org の public_id or domain を保持）
- `representing_organization_id`（string）
- この 2 つが「Organization が Avatar を所有する」と「Avatar が Organization を代表する」を分離している

### 委譲・転送設計の推定

**中程度の推定（根拠あり）**：

Organization
Unit に関して「所有権移転・委譲」の直接的な ADR は発見できなかったが、以下の設計パターンが示唆する：

1. `avatar_ownership_periods`（`starts_at`/`ends_at`）→
   Avatar 所有権の**時間追跡**設計は「所有権が変わる」前提を内包している
2. `avatar_memberships` の validity dates → operate 権限の期間管理
3. `AvatarGrant` → Avatar 操作権の「配布・付与・剥奪」設計
4. Organization が Avatar を「own」し、Account が Avatar を「operate」するという分離 →
   **Organization/Unit が変わっても Avatar が継続する設計**を示唆

**弱い推定（根拠薄）**：

- Organization Unit を「別 Organization に渡す（detachable
  unit）」設計の痕跡は今回の調査では ADR 等に明示的な記述なし
- `parent_id`
  が**不変**という設計（`adr/collective-hierarchy-model.md`）は、Unit の「切り離し・再配置」を意図的に制約している可能性もある
- 今後「Unit の ownership transfer」が設計課題になる場合、`parent_id` 不変制約との整合性検討が必要

### Organization Unit の性質（現時点の推定）

> **Organization Unit は「時間追跡可能な、Account の帰属先となる階層ノード」**。  
> 「切り離して他人に渡す」設計よりも、「Account が Unit を通じて Workspace に帰属し、そのコンテキストで Avatar を operate する」設計に重心がある。

---

## 7. Sign に残っているもの / Acme に移すべきもの

### Acme に移してよいもの（明示 ADR あり）

| 機能                         | 理由                                       | 根拠ファイル                                          | 移行リスク                 |
| ---------------------------- | ------------------------------------------ | ----------------------------------------------------- | -------------------------- |
| OIDC provider endpoints      | Acme が唯一の IdP                          | `adr/sign-residual-idp-surface-retirement.md`         | 高（クライアント設定変更） |
| refresh token rotation       | Acme がトークン権威                        | `adr/acme-session-and-token-authority.md`             | 高（セッション継続性）     |
| step-up freshness コミット   | Acme がセッション状態管理                  | 同上                                                  | 中                         |
| session 一覧・logout UI      | Acme が session management 権威            | 同上                                                  | 低（既に進行中）           |
| email/telephone 設定書き込み | 既に Acme /identity/ に移動済み            | `docs/architecture/sign-settings-to-acme-identity.md` | **移行済み**               |
| withdrawal                   | 既に Acme /identity/withdrawals に移動済み | 同上                                                  | **移行済み**               |
| MFA 設定                     | 既に Acme /identity/mfa に移動済み         | 同上                                                  | **移行済み**               |

### Sign に残すべきもの（WebAuthn URL binding 例外）

| 機能                                    | 理由                                              | 根拠ファイル                               | 残すべき境界                                 |
| --------------------------------------- | ------------------------------------------------- | ------------------------------------------ | -------------------------------------------- |
| WebAuthn/passkey ceremony 実行          | `id.example.com` に RP ID binding                 | `adr/sign-credential-gateway-surface.md`   | ceremony 実行のみ（grant 受取・result 返却） |
| TOTP 検証                               | ceremony 実行の文脈                               | 同上                                       | 同上                                         |
| Google/Apple OAuth コールバック         | コールバック URL が Sign の domain に binding     | 同上                                       | コールバック受取・result 返却のみ            |
| `/.well-known/jwks.json`（Sign 署名鍵） | Jump RT トークン用（OIDC id-token ではない）      | `docs/security/session-token-authority.md` | Sign 固有の RT 署名鍵のみ                    |
| promotional email unsubscribe           | Public・token-verified（Sign preference surface） | `docs/architecture/preference.md`          | token 検証・idempotent 書き込みのみ          |

### 判断が難しいもの

| 機能                                            | 理由                                                                                                            | 追加で見るべきファイル                                                             |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Sign::App::Settings 残骸コード（redirect のみ） | 既に Acme にリダイレクト済みだが、Sign 側のルートとコントローラが残っている。削除していいか、互換性維持が必要か | `plans/backlog/sign-acme-boundary-remediation.md` / `config/routes/sign.rb` の全体 |
| Credential inventory 表示                       | Sign に passkey/TOTP の inventory があるが、これも Acme /identity/ に移すべきか                                 | `app/controllers/sign/app/settings/` 全体                                          |
| sign-up フロー自体                              | Sign で email 収集・確認→Acme で account 作成、というフローの境界が実装上明確か                                 | `app/controllers/sign/app/sign/up/` 全体                                           |

---

## 8. 現在の設計変更への影響分析

### 一致している点

1. **identity = singular resource** → 既に
   `resource :identity`（singular）がルートに存在し、`acme/app/identity/` コントローラ群が整備済み
2. **preference = singular resource** → 既に `resource :preference`（singular +
   nested）がルートに存在
3. **account / avatar = plural resources** → 既に `resources :accounts`, `resources :avatars`
   が存在し、public_id ベース lookup が実装済み
4. **sign から identity 管理を移す** → email/telephone/withdrawal/MFA/session は既に Acme
   /identity/ に移行済み
5. **organization unit の parent_id 不変制約** → `adr/collective-hierarchy-model.md`
   に明示。今回の変更でこれを壊すリスクは低い

### 衝突・注意点

1. **Organization の識別子が `domain`（`public_id` ではない）**  
   `resources :organizations, param: :public_id` に揃えるには Organization モデルへの `public_id`
   追加が必要。または `domain` を param として使う設計とする。

2. **`ClientAccount` vs `Persona`（Account concern）の命名衝突**  
   `resources :accounts` の `:account` が指す概念は `Persona`（Account
   concern）であり、`ClientAccount`（RP binding record）ではない。controller・lookup
   service でこの区別を明示的に維持する必要がある。

3. **Avatar は Com では存在しない**  
   `acme.com.*` の routes に `resources :avatars`
   を置くと設計違反。Surface 別にルートを分ける必要がある。

4. **Sign 側の残留コードとのルート衝突リスク**  
   Sign::App::Settings コントローラが Acme にリダイレクトするだけの状態で残っている。これらを削除するタイミングと、URL 互換性（bookmarks 等）の検討が必要（`plans/backlog/sign-acme-boundary-remediation.md` 参照）。

5. **preference は Acme で書かない**  
   Acme は preference の読み取り専用コンシューマ。`resource :preference` を Acme に置く場合、`show`
   のみ（または preference 関連 lookup のみ）とし、`update` を Acme に置くことは Sign preference
   surface の権威を侵す。

---

## 9. 結論：推奨する Acme resource 構造

### 設計上の前提確認

- identity と preference は **singular resource**（当該 surface の current user の文脈）
- account / organization / avatar は **plural
  resources**（public_id で lookup できる外部参照可能な主体）
- preference の**書き込みは Sign preference surface** が権威（Acme は read-only）
- Organization の param は `public_id` か `domain` かを確定する必要あり（現在 `domain`
  が unique 識別子）
- Avatar は **App と Org のみ**（Com には置かない）

### 推奨する Acme routes（概念モデル）

```ruby
# App surface: acme.app.*
constraints host: /\Aacme\.app\./ do
  scope module: :acme do
    scope module: :app do

      # singular: current logged-in identity（credential / session 管理）
      resource :identity, only: [:show] do
        resource :birthdate, only: [:show]
        resources :emails, param: :id do        # :id = public_id
          resources :redeliveries, only: [:create]
          resources :registrations, only: [:new, :create, :edit, :update]
        end
        resources :telephones, param: :id do
          resources :registrations, only: [:new, :create, :edit, :update]
        end
        resources :sessions, param: :id, only: [:index, :show, :destroy] do
          resource :revocation, only: [:create]
          resources :revocations, only: [] do
            collection do
              resource :all,    only: [:create]
              resource :others, only: [:create]
            end
          end
        end
        resources :secrets, param: :id do      # secret credentials
          resources :rotations, only: [:new, :create]
          resources :removals,  only: [:new, :create]
        end
        resource :recovery_secret, only: [:show]
        resource :mfa, only: [:show, :update] do
          resource :reset, only: [:show, :create]
        end
        resource :withdrawal, only: [:new, :create, :edit, :update, :destroy]
        resources :activities, only: [:index]
        resources :revocations, only: [] do
          collection do
            resource :all,    only: [:create]
            resource :others, only: [:create]
          end
        end
      end

      # singular: current user の preference（read-only。書き込みは Sign preference surface）
      resource :preference, only: [:show]

      # plural: public_id で lookup できる外部参照可能な主体（App/Org のみ Avatar あり）
      resources :accounts,      param: :id, only: [:index, :show]   # :id = public_id of Persona
      resources :organizations, param: :id do                        # :id = public_id or domain（要決定）
        resources :memberships, only: [:index, :show, :create, :destroy]
      end
      resources :avatars, param: :id do                              # :id = public_id
        # SNS domain のリソース（follow/block/mute 等）はここに置かない
      end

    end
  end
end

# Com surface: acme.com.*
# Avatar なし・Organization は Company として存在
constraints host: /\Aacme\.com\./ do
  scope module: :acme do
    scope module: :com do
      resource  :identity,     only: [:show] { ... }
      resource  :preference,   only: [:show]
      resources :accounts,     param: :id, only: [:index, :show]
      resources :organizations, param: :id  # Company
      # resources :avatars は置かない（Com では Avatar 不可）
    end
  end
end

# Org surface: acme.org.*
constraints host: /\Aacme\.org\./ do
  scope module: :acme do
    scope module: :org do
      resource  :identity,     only: [:show] { ... }
      resource  :preference,   only: [:show]
      resources :accounts,     param: :id, only: [:show]  # Org は index を show にリダイレクト
      resources :organizations, param: :id                # Bureau
      resources :avatars,      param: :id                 # Org は Avatar あり
    end
  end
end
```

### 残課題（実装前に決定が必要）

1. **Organization の param**: `domain` のままにするか、`public_id` を追加して揃えるか
2. **`resources :accounts` が指す model**: `Persona`（Account
   concern）であることをコントローラ命名・コメントで明示する
3. **Sign 側の残留コード削除タイミング**: `plans/backlog/sign-acme-boundary-remediation.md`
   のスコープと優先度確認
4. **preference の `show` Acme に置くか**:
   Acme が preference を read-only 表示する UI を持つかどうか（現状 preference 表示は Sign 側にある可能性）
5. **OrganizationUnit の routes**: 現時点では Acme に明示的な routes がない。Unit を plural
   resource として扱う場合、`organizations/:id/units` という nesting が自然
