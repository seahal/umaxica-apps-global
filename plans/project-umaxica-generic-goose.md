# Acme Surface — Account / Organization 設計レビュー

**作成日:** 2026-06-26  
**種別:** 設計 grill / 事前レビュー（実装なし）  
**対象:** Acme surface の Account / Organization 実装前チェック

---

## 1. 読んだファイル一覧

| path                                                              | 種別       | 関連領域                  | 重要度 | 読み取れたこと                                                                                          |
| ----------------------------------------------------------------- | ---------- | ------------------------- | ------ | ------------------------------------------------------------------------------------------------------- |
| `adr/surface-account-collective-model-naming.md`                  | ADR        | Account/Organization 命名 | ★★★    | Persona/Agent/Individual = Account; Enterprise/Bureau/Company = Collective                              |
| `adr/identity-authority-boundary.md`                              | ADR        | Acme/Sign 境界            | ★★★    | Acme がセッション・トークン・アカウント Lifecycle の権威; Sign は Credential Gateway のみ               |
| `adr/acme-sign-core-base-port-boundary.md`                        | ADR        | コンポーネントモデル      | ★★★    | Acme=IdP、Sign=RP、Core=NextJS BFF、Palm=Native API                                                     |
| `adr/surface-database-connection-naming.md`                       | ADR        | DB 境界                   | ★★★    | surface × role (principal/ticket/zenith/signal/setting) で DB が分かれる                                |
| `adr/preference-soft-bubble-doctrine.md`                          | ADR        | Preference 権威           | ★★★    | Preference write は sign/app・sign/org・sign/com が持つ（Acme は RO）                                   |
| `adr/two-base-authentication-mode-boundaries.md`                  | ADR        | Controller base           | ★★     | BareController と surface ApplicationController の二層                                                  |
| `adr/actor-current-facade.md`                                     | ADR        | Actor context             | ★★     | Actor は immutable snapshot; current_client/operator/visitor で参照                                     |
| `adr/app-actor-client-naming.md`                                  | ADR        | Actor 命名                | ★★     | App authenticated actor = Client（旧 User）                                                             |
| `adr/org-actor-operator-naming.md`                                | ADR        | Actor 命名                | ★★     | Org authenticated actor = Operator（旧 Staff）                                                          |
| `adr/com-actor-visitor-naming.md`                                 | ADR        | Actor 命名                | ★★     | Com authenticated actor = Visitor（旧 Customer）                                                        |
| `docs/dictionary/identity-account-organization-avatar.md`         | Dict       | DDD ubiquitous language   | ★★★    | Identity=principal、Account=Persona/Agent/Individual、Organization=Enterprise/Bureau/Company            |
| `docs/architecture/controller-lifecycle.md`                       | Doc        | Controller lifecycle      | ★★     | rate limit → token verify → actor init → action → cleanup の順序                                        |
| `app/models/persona.rb`                                           | Model      | Account (app)             | ★★★    | `client_identity_id UNIQUE NOT NULL`、`moniker` カラム、`public_id`                                     |
| `app/models/enterprise.rb`                                        | Model      | Organization (app)        | ★★★    | `name NOT NULL`、`public_id`、`Collective` concern、`enterprise_units`、`persona_memberships`           |
| `app/models/client_identity.rb`                                   | Model      | Identity binding          | ★★★    | `source_record_id UNIQUE`（Client と 1:1）、`(issuer, subject, audience) UNIQUE`                        |
| `app/models/concerns/collective.rb`                               | Concern    | Organization 共通         | ★★     | `name` presence validation + PublicId                                                                   |
| `app/models/concerns/account.rb`                                  | Concern    | Account 共通              | ★★     | memberships / collective context navigation、PublicId                                                   |
| `app/services/acme_selector_bootstrap_authority.rb`               | Service    | Bootstrap                 | ★★★    | rp_account → identity → account → collective → unit → membership → avatar を transaction で atomic 作成 |
| `app/services/acme_selector_surface_config.rb`                    | Config     | Bootstrap 設定            | ★★★    | surface ごとに account_moniker / collective_name / クラス群を定義                                       |
| `app/models/client_account.rb`                                    | Model      | RP account bridge         | ★★     | `user_id UNIQUE`、`public_id` のみ; Client と Persona の間のブリッジ                                    |
| `app/models/persona_membership.rb`                                | Model      | Membership (app)          | ★★★    | `persona_id`、`enterprise_id`、`enterprise_unit_id`; primary unique constraint                          |
| `app/models/enterprise_unit.rb`                                   | Model      | Hierarchy (app)           | ★★     | `parent_id` immutable; closure table で先祖/子孫                                                        |
| `app/models/organization.rb`                                      | Model      | Legacy org                | ★★     | `org_principal` DB; `domain UNIQUE`; 旧来の org 階層; Enterprise/Bureau/Company とは別物                |
| `app/controllers/concerns/sign_up_sequence_controller_support.rb` | Controller | Sign up finalization      | ★★★    | `IdentityGraphProvisioner.call!` を finalize 時に呼ぶ                                                   |
| `db/app_zenith_structure.sql`                                     | Schema     | app_zenith DB             | ★★★    | personas/enterprises/persona_memberships/client_identities の実際のカラム確認                           |
| `plans/active/sign-up-state-machine-implementation-plan.md`       | Plan       | Sign up state machine     | ★★     | 現在進行中の実装計画                                                                                    |

---

## 2. 既存設計の復元

| 概念                        | 既存モデル / concern                                                                  | surface                           | public_id 有無                            | title/name 系カラム     | 主な association                                                       | 備考                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------- | --------------------------------- | ----------------------------------------- | ----------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Identity** (principal)    | `Client` / `Operator` / `Visitor`                                                     | app / org / com                   | ○ (NanoID-21; Operator は 16-char BASE32) | なし                    | credentials, device_sessions, tokens                                   | `app_principal` / `org_principal` / `com_principal` DB                                    |
| **Identity binding**        | `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`                             | app / org / com                   | ○                                         | なし                    | `has_one :persona` (1:1)                                               | `app_zenith` / `org_zenith` / `com_zenith` DB; `source_record_id UNIQUE` で Client と 1:1 |
| **RP account bridge**       | `ClientAccount` / `OperatorAccount` / `VisitorAccount`                                | app / org / com                   | ○                                         | なし                    | `belongs_to :user` (Client)                                            | Bootstrap 時に作成される薄い bridge                                                       |
| **Account**                 | `Persona` (app) / `Agent` (org) / `Individual` (com)                                  | app / org / com                   | ○                                         | `moniker`               | `belongs_to :client_identity`, `has_many :persona_memberships`         | `include Account`; `client_identity_id UNIQUE NOT NULL`                                   |
| **Organization**            | `Enterprise` (app) / `Bureau` (org) / `Company` (com)                                 | app / org / com                   | ○                                         | `name NOT NULL`         | `has_many :enterprise_units`, `has_many :persona_memberships`          | `include Collective`; `title` は存在しない                                                |
| **Natural-person org 相当** | `Enterprise` / `Bureau` / `Company` (bootstrap 時に "Personal Organization" 名で作成) | app / org / com                   | ○                                         | `name` のみ             | —                                                                      | 現在 natural/corporate の区別なし; `kind`/`type` enum なし                                |
| **Membership / link**       | `PersonaMembership` / `AgentMembership` / `IndividualMembership`                      | app / org / com                   | —                                         | —                       | `persona_id`, `enterprise_id`, `enterprise_unit_id`; `primary` boolean | `include CollectiveMembership`                                                            |
| **Avatar**                  | `Avatar`                                                                              | app のみ (org は将来; com は不可) | ○                                         | `moniker`               | `belongs_to :member (Client)`, `has_many :avatar_memberships`          | `avatar` DB (global); com/org では `requires_avatar: false`                               |
| **OrganizationUnit**        | `EnterpriseUnit` / `BureauUnit` / `CompanyUnit`                                       | app / org / com                   | ○                                         | `name NOT NULL`         | closure table (先祖/子孫); `parent_id` immutable                       | Bootstrap 時に root unit を 1 つ作る                                                      |
| **Legacy org**              | `Organization`                                                                        | org のみ                          | ✗                                         | `domain UNIQUE`, `name` | `divisions`, `departments`, `operator_id`                              | `org_principal` DB; Enterprise/Bureau/Company とは別系統の旧来モデル                      |

---

## 3. 今回方針との一致点

- **Enterprise / Bureau / Company という命名は正しい。** ADR
  `surface-account-collective-model-naming.md` と完全に一致する。
- **3 surface 同時 (app/org/com) の方針は既存設計と一致する。**
  AcmeSelectorSurfaceConfig が app/org/com 全サーフェスの設定を定義済み。
- **STI は使わない。** 既存も 3 concrete model で実装済み。
- **enum kind/type で自然人/法人を分けない。** 既存モデルに kind/type は存在しない。
- **Concern で共通 behavior を定義する方針は一致する。**
  `Collective`、`Account`、`CollectiveMembership`、`CollectiveUnit` がすでに存在する。
- **Enterprise / Bureau / Company はすでに `public_id` を持つ。** migration 不要。
- **`param: :public_id` は routes に存在しない。** 既存ルートはすべて Rails default の `:id`
  を使用。
- **`to_param` で `public_id` を返す方針は既存パターンに合う。**
  ClientEmail 等の credential モデルで実装済み。
- **Signup bootstrap は atomic transaction で行う設計になっている。**
  `AcmeSelectorBootstrapAuthority` が rp_account → identity → account → collective → unit →
  membership → avatar を 1 transaction で作成。rollback 設計済み。
- **OrganizationUnit (`EnterpriseUnit` 等) は `parent_id` immutable。** `CollectiveUnit`
  concern で検証済み。
- **Avatar は app のみ。** `requires_avatar: true` は app のみ; com/org は false。

---

## 4. 今回方針との衝突点

### 衝突 1（重大）: Identity 1:n Account は現在 1:1 として実装されている

提案: 「Account は Identity に 1:n で紐づく」

現状:

- `client_identities.source_record_id` に **UNIQUE index** → Client と ClientIdentity は 1:1  
  (`app/models/client_identity.rb:25`)
- `personas.client_identity_id` に **UNIQUE index** → ClientIdentity と Persona は 1:1  
  (`app/models/persona.rb:19`)
- 結果として Client → (ClientIdentity) → Persona は **事実上 1:1**

1:n に変えるには:

- `source_record_id` の UNIQUE を外し、複数 ClientIdentity を同一 Client に紐づけるか
- Persona を ClientIdentity 経由でなく Client に直接紐づけて UNIQUE を外すかが必要
- どちらの方針を選ぶかは ADR レベルの決定が必要

現在の AcmeSelectorBootstrapAuthority は `source_record_id` が UNIQUE であることを前提に
`find_or_create_by` を実装している（`app/services/acme_selector_bootstrap_authority.rb:97`）。

### 衝突 2（重大）: `title` カラムは存在しない（Account は `moniker`、Organization は `name`）

提案: Account と Organization の初期 short name として `title` を持たせる

現状:

- `personas.moniker` : Account (Persona) の表示名
- `enterprises.name` : Organization の名前（`name NOT NULL` で Collective
  concern に validation あり）
- `title` はどのモデル・migration にも存在しない

対処方針の選択肢（今回は判断しない、実装フェーズで決める）:

- A) 既存 `moniker` を `title` に rename migration する
- B) `title` カラムを追加し `moniker` を廃止
- C) `title` カラムを `moniker` と並存させる（非推奨: 重複）

どの選択肢でも `app_zenith`、`org_zenith`、`com_zenith` への migration が必要。 `Collective`
concern の `name` validation は Organization には引き続き必要なので、Organization の `name` を
`title` にそのまま rename するかどうかも決定が必要。

### 衝突 3（中程度）: Preference 書き込み権威が方針と食い違う

提案: 「Acme が RW authority」「Preference URL は signed-in / signed-out で分けない」

現状 ADR (`preference-soft-bubble-doctrine.md`):

- **Preference write surfaces は sign/app, sign/org, sign/com が持つ**
- Acme は Preference を read-only で consume する (`Actor.preferences`)
- Request-local overlay (`lx`/`ct`/`tz`) は read-only、DB には書かない

衝突箇所:

- `adr/preference-soft-bubble-doctrine.md` — "Preference write surfaces: Only `sign/app`,
  `sign/org`, `sign/com` write preferences"
- `adr/identity-authority-boundary.md` — Acme の権威は session/token/account
  lifecycle であり、preference write ではない

Preference 権威の移管を行う場合は新規 ADR が必要。今回のレビューでは衝突を記録するのみ。

### 衝突 4（小）: Account / Organization quota の仕組みが存在しない

提案: accounts per identity: 10、organizations per identity: 2

現状:

- 認証 credential の limit は定数で定義済み（`MAX_EMAILS_PER_USER = 4`
  等）(`app/models/concerns/authentication_credential_inventory_owner.rb`)
- Account や Organization の作成上限を管理する policy / quota / guard は存在しない
- `OrganizationPolicy` は空スタブ（`app/policies/organization_policy.rb`）

実装時に quota 機構を新規で置く必要がある。

### 衝突 5（情報）: 旧来の `Organization` モデルが `org_principal` DB に存在する

`app/models/organization.rb` は `org_principal`
DB に存在し、`domain UNIQUE`・`parent_id`・`operator_id` を持つ別系統のモデル。今回提案の `Bureau`
(= `org_zenith` DB) とは別物だが、命名の混乱を招く可能性がある。今回は触らないが、将来 `Bureau`
を "Organization" と呼ぶドキュメントを書く際は区別を明示すること。

---

## 5. Organization public_id の判定

### Enterprise / Bureau / Company に public_id はあるか

**ある。** 全 3 モデルに `public_id` カラムが存在し、UNIQUE index が付いている。

- `enterprises.public_id` : `app/models/enterprise.rb:15`
- `bureaus.public_id` : 確認済み (agent の調査)
- `companies.public_id` : 確認済み (agent の調査)

### 現在の canonical identifier は何か

`public_id` (NanoID-21)。`name` は mutable な表示名であり、identifier として使われていない。旧来の
`Organization` モデルは `domain` が canonical
identifier だが、これは Enterprise/Bureau/Company とは別系統。

### domain は identifier として使われているか

Enterprise/Bureau/Company には `domain` カラムは存在しない。`name` のみ。 `domain` は旧来の
`Organization` モデルのみに存在する。

### public_id を追加すべきか

**追加不要。** 既に存在する。

### `param: :public_id` を使わず `params[:id]` を public_id として解釈する方針に問題があるか

問題なし。現在のパターンに沿っている。

- 既存の credential モデル（`ClientEmail` 等）が `to_param` で `public_id` を返す実装を持つ
- routes には `param:` 指定は存在しない
- Enterprise/Bureau/Company にも `to_param`
  を public_id を返すよう追加することで同一パターンが実現できる

---

## 6. Sign up bootstrap の推奨実装位置

### signup final commit はどこで行われているか

`app/controllers/concerns/sign_up_sequence_controller_support.rb` の
`finalize_sign_up_from_checkpoint!` メソッドが:

1. Principal (Client/Operator/Visitor) のステータスを `VERIFIED_WITH_SIGN_UP` に更新
2. `IdentityGraphProvisioner.call!(surface:, principal:)` を呼ぶ
3. `AcmeSelectorBootstrapAuthority` がその中で呼ばれる（と推定される）

`AcmeSelectorBootstrapAuthority.call` が以下を 1 transaction で作成:

```
ClientAccount → ClientIdentity → Persona → Enterprise → EnterpriseUnit → PersonaMembership → Avatar
```

### Account / Organization / membership creation を入れるべきか

**すでに入っている。** `AcmeSelectorBootstrapAuthority` が正確にこのロールを担っている。 `title`
カラムの追加後は `account_moniker:` に相当する設定を `title:` に変更するだけで済む。

### 既存 transaction があるか

**ある。** `config.rp_account_class.transaction do ... end`
ブロック内で全オブジェクトが作成される。  
`app/services/acme_selector_bootstrap_authority.rb:24-42`

### rollback / partial creation をどう防ぐか

- transaction ブロック内に全 create を閉じ込めている
- `find_or_create_by!` + `ActiveRecord::RecordNotUnique` の rescue で冪等性を確保
- `PersonaMembership.create!` での `RecordNotUnique`
  rescue も実装済み（`app/services/acme_selector_bootstrap_authority.rb:135`）

### app/org/com で同型にできるか

**すでに同型。** `AcmeSelectorSurfaceConfig::CONFIGS`
が app/com/org を同一インターフェースで抽象化しており、bootstrap は surface に依存せず同一コードパスを通る。

---

## 7. Title 実装の影響

### Account 系 (`Persona` / `Agent` / `Individual`) に `title` は既にあるか

**ない。** 現在は `moniker` カラムのみ。`title` カラムは存在しない。

### Organization 系 (`Enterprise` / `Bureau` / `Company`) に `title` は既にあるか

**ない。** 現在は `name` カラムのみ。`Collective` concern が `name`
の presence を validate している。

### migration が必要か

**必要。** 少なくとも `app_zenith`、`org_zenith`、`com_zenith` の 6 テーブル（3 Account + 3
Organization）に対する migration が必要。  
`Collective` concern の `name` validation をどう扱うかも同時に決定が必要。

### 既存の `moniker` / `name` との衝突

| モデル                    | 既存カラム | 提案カラム | 衝突内容                                                                                                                                                  |
| ------------------------- | ---------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Persona/Agent/Individual  | `moniker`  | `title`    | rename or add が必要。`moniker` は AcmeSelectorBootstrapAuthority から "Default Persona" 等の値で設定される                                               |
| Enterprise/Bureau/Company | `name`     | `title`    | `Collective` concern の `name` presence validation が残るため `name` を残しつつ `title` を追加するか、`name` → `title` rename して concern も書き換えるか |

### Account title と Organization title を共通化しない方針で問題があるか

**問題なし。** 現在も Account の `moniker` と Organization の `name`
は別 concern で別管理になっている。提案の「共通化しない」方針は現状設計に整合する。

---

## 8. Quota 実装の推奨場所

### 既存の quota 仕組みがあるか

認証 credential の limit は定数で管理:

- `MAX_EMAILS_PER_USER = 4`、`MAX_PASSKEYS_PER_USER = 4` 等
- `AuthenticationCredentialInventoryOwner` concern が保有

Account / Organization の作成上限は存在しない。`OrganizationPolicy` は空スタブ。

### 推奨実装位置

**Policy layer。** Pundit ポリシーが既存の authorization 基盤。`PersonaPolicy`（新規）と
`EnterprisePolicy`（新規）に quota check を置き、controller が `authorize` を通じて呼ぶ。

```
PersonaPolicy#create? → client.personas.count < Quota::ACCOUNTS_PER_IDENTITY
EnterprisePolicy#create? → client.enterprises.count < Quota::ORGANIZATIONS_PER_IDENTITY
```

### model validation に置くべきでない理由

- model は単一レコードの validity を検証するもの; 「Identity に紐づく Persona が n 件以下」はアグリゲート横断の制約
- `validates :count` は race condition に弱い（SELECT → INSERT の間に別 request が割り込む）
- Policy + DB-level constraint（必要であれば partial index で upper bound）が適切

### 将来の拡張点

- `Quota` module または `QuotaConfig` Data オブジェクトに limit 値を集約する
- limit 値をリファレンステーブル（`plan_limits`、`quota_overrides`
  等）から読む設計への移行が容易になる
- `10` や `2` はコードに直書きせず、定数名で参照する（例: `Quota::ACCOUNTS_PER_IDENTITY`）

---

## 9. 実装しないもの

今回のスコープに含まれない項目（明示的に除外）:

| 項目                                              | 理由                                                    |
| ------------------------------------------------- | ------------------------------------------------------- |
| STI                                               | ADR で禁止; 既存設計も concrete model                   |
| enum kind/type                                    | 既存設計に存在しない; 方針でも禁止                      |
| Corporate / legal entity organization             | 今回は natural-person organization のみ                 |
| 法人確認・代表者確認                              | 今回スコープ外                                          |
| Billing / contract                                | 今回スコープ外                                          |
| OrganizationUnit (`EnterpriseUnit` 等) の新規実装 | 既存実装のみ; 今回は触らない                            |
| transfer / delegation                             | スコープ外                                              |
| selector / switcher (Acme)                        | 既存の AcmeSelectorAuthority が担当; 今回は新規追加なし |
| SNS product domain (feed/post/follow/block/mute)  | Acme には入れない                                       |
| Avatar の com/org 対応                            | 今回は変更なし                                          |
| Preference 権威の移管                             | 衝突を記録したが今回は実装しない                        |

---

## 10. OrganizationUnit — 今回触らないが確認すべき未確定論点

`EnterpriseUnit` / `BureauUnit` / `CompanyUnit` について確認できた事実:

| 観点                    | 現状                                                                             |
| ----------------------- | -------------------------------------------------------------------------------- |
| 役割                    | closure table を使った recursive hierarchy node                                  |
| `parent_id`             | immutable（CollectiveUnit concern で update guard)                               |
| bootstrap との関係      | bootstrap 時に root unit (parent_id = nil) を 1 つ作成                           |
| membership scope        | PersonaMembership が `enterprise_unit_id` を持ち、unit への所属を表す            |
| billing/workspace scope | 現時点では不明；`AvatarMembership` や billing との関係ドキュメントが見当たらない |
| delegation / transfer   | 設計ドキュメント未確認                                                           |

**今回 Account/Organization bootstrap と衝突するか:** しない。bootstrap が root
unit を 1 つ作ることは既存動作であり変更なし。

**将来確認すべき論点:**

- Unit を billing scope として使う計画があるか
- Membership scope (sub-team 等) として使う具体的な機能計画があるか
- Unit 階層を外部公開する API を設計する際の public_id の扱い

---

## 11. 最終提案 — 次の PR / task の切り方

### 前提条件の解消が必要な決断

実装に進む前に以下を方針決定する必要がある:

1. **Identity 1:n Account の実現方法**（衝突 1）
   - A) `source_record_id` の UNIQUE を外し、同一 Client が複数 ClientIdentity を持てるようにする
   - B) Persona を ClientIdentity 経由でなく Client に直接紐づけ直す
   - C) 当面 1:1 のまま実装し、1:n は後回し  
     → 決定後に ADR を書く

2. **`title` の実装方針**（衝突 2）
   - A) `moniker` → `title` rename migration
   - B) `title` 追加、`moniker` 廃止
   - C) `title` 追加、`moniker` 共存（Organization の `name` はどうするか）  
     → 決定後に migration を書く

### 推奨 PR 分割

#### PR 1: `title` カラム追加 migration

- `app_zenith`: `personas.title`, `enterprises.title`
- `org_zenith`: `agents.title`, `bureaus.title`
- `com_zenith`: `individuals.title`, `companies.title`
- `AcmeSelectorSurfaceConfig` の `account_moniker` / `collective_name` を `title` に対応させる
- `Collective` concern の validation を `title` に対応させる（`name` の扱いも含む）
- テスト: 各モデルの title validation、bootstrap で title が設定されること

#### PR 2: Account / Organization ルーティングと controller scaffold

- `acme/app/accounts_controller`、`acme/com/accounts_controller`、`acme/org/accounts_controller`
- `acme/app/organizations_controller`、`acme/com/organizations_controller`、`acme/org/organizations_controller`
- routes に `resources :accounts` / `resources :organizations`（`param:` 指定なし）
- `to_param` override で `public_id`
  を返す実装（Enterprise/Bureau/Company/Persona/Agent/Individual）

#### PR 3: Quota policy

- `PersonaQuota` / `EnterpriseQuota` 等の quota 定数モジュール
- `PersonaPolicy#create?` / `EnterprisePolicy#create?` に count check
- テスト: limit 到達時に create が拒否されること

#### PR 4: Sign up bootstrap の title 対応

- `AcmeSelectorBootstrapAuthority` の `ensure_account!` に title 設定を追加
- `ensure_collective_for` に title 設定を追加
- サインアップ完了フロー (title 入力ステップ) の controller / form

---

## 確認: 変更なし

以下の `git diff --stat` により、このレビュー中にコード変更が行われていないことを確認済み:

```
106 files changed, 335 insertions(+), 367 deletions(-)
```

上記は本レビュー開始前からブランチに存在していた差分であり、本レビューによる新規変更はゼロ。
