# Acme app surface: Account / Organization / Avatar 管理 + Switcher 実装計画

## Context（なぜこの変更をするか）

Acme app surface に、ログイン後の Account / Organization /
Avatar 管理導線と、現在利用中 context（current account / organization /
avatar）を変更する Switcher を Rails way で整える。

設計方針は「entity の CRUD は plural resources、current context の表示・切替は singular `/switcher`
に集約、selector は login-time ceremony 専用」。selector /
switcher の責務分離は既存 ADR と整合する（`adr/identity-authority-boundary.md`、`plans/selector-full-access-fluttering-thimble.md`：selector は ceremony 前選択、switcher は post-login
context 変更で Acme authority）。

### 既存リポジトリ状態（重要：greenfield ではない）

調査の結果、`config/routes/acme.rb` の app surface には **既にコミット済み**で以下が存在する:

- `resource :switcher`（`Acme::App::SwitchersController`、`FullAccessController` 継承、現状 stub）
- `resources :organizations`（index/show/new/create/edit/update）+ nested `memberships`
- `resource :selector`（`SelectorsController`、`PreAccessController`、login ceremony）
- **本設計が禁止する singular current routes が既存かつテスト済み**:
  - `resource :account`（`AccountsController`）
  - `resource :avatar`（`AvatarsController`、FullAccess）
  - `resource :organization, as: :current_organization`（`OrganizationsController`）
  - これらは `test/controllers/acme/self_service_routes_test.rb` で self-service HTML
    page として検証されている
- **orphan**: `app/controllers/acme/app/current/organizations_controller.rb` と
  `app/views/acme/app/current/{organizations,avatars}/` は、どの route からも参照されない放棄された
  `current/` 実装（本設計が禁止する `scope module: :current` 系）
- switcher の atomic validate-then-persist ロジックは `AcmeSelectorAuthority.select`
  に既に実装済み（account/org/avatar の組合せを実 candidate に照合 → session token に atomic 永続）

### ユーザ決定（本計画の前提）

1. 既存 singular current routes は **削除**し、plural + `/switcher` に統合する（app surface のみ）。
2. switcher の validate-then-switch は **薄い `AcmeSwitcherAuthority`
   を新設**し、candidate 解決・検証・永続ロジックを selector と共有する。
3. com / org surface は触らない（app surface のみ）。

---

## 目標ルート（app surface のみ）

```rb
resources :accounts,      only: %i[index new create show edit update]
resources :organizations, only: %i[index new create show edit update]  # 既存維持（memberships nested も維持）
resources :avatars,       only: %i[index new create show edit update]
resource  :switcher,      only: %i[show update]                          # 既存維持（stub を実装）
# resource :selector / resource :identity は維持
# singular resource :account / :avatar / :organization(current_organization) は削除
```

期待 controller（plural naming、singular `:switcher` でも controller は plural `switchers`）:

```
app/controllers/acme/app/accounts_controller.rb
app/controllers/acme/app/organizations_controller.rb
app/controllers/acme/app/avatars_controller.rb
app/controllers/acme/app/switchers_controller.rb
```

---

## 変更詳細

### 1. Routes — `config/routes/acme.rb`（app surface block、~163–178 行のみ）

- 削除: `resource :organization, ..., as: :current_organization`（167 行）
- 削除: `resource :avatar, only: %i(show edit update destroy)`（170 行）
- 削除: `resource :account, only: %i(show edit update)`（173 行）
- 追加: `resources :accounts, only: %i(index new create show edit update)`
- 追加: `resources :avatars, only: %i(index new create show edit update)`
- 維持: `resources :organizations`（既に目標 action 集合と一致）+ nested `memberships`
- 維持: `resource :switcher` / `resource :selector` / `resource :identity`
- **com（~341–345 行）/ org（~560–566 行）の singular routes は変更しない**

`scope module: :current, as: :current` は追加しない（既存にも無い）。

### 2. Controllers — `app/controllers/acme/app/`

全 4 controller を full-login guard 配下に置く（`FullAccessController` 継承 → anonymous / partial
ceremony / selector-only 状態は `require_selected_actor_context!` で拒否）。

- `accounts_controller.rb`: `ApplicationController` → `FullAccessController`
  に変更。singular（id 無し）から plural CRUD へ作り替え。`index`
  = 利用可能 account 一覧、`show/edit/update` = `params[:id]` (public_id) を
  **current_client の available 集合内に scope して find**（他人は not found）。 `new/create`
  は最小 skeleton（authorize + render/redirect、既存 `OrganizationsController#create`
  の stub スタイルに合わせる）。account model は
  `AcmeSelector.config_for(:app).account_class`(=`Persona`)。
- `avatars_controller.rb`: 既に `FullAccessController`。singular から plural CRUD へ。avatar は
  `avatar_assignments(user_id: current_client.id)` に scope して find。
- `organizations_controller.rb`: `ApplicationController` → `FullAccessController`
  に変更。既存 plural action を維持しつつ `show/edit/update`
  を current_client が membership を持つ organization に scope。nested
  `organizations/memberships_controller.rb` は変更しない。
- `switchers_controller.rb`: stub を実装。
  - `show`:
    `AcmeSwitcherAuthority.current(surface: :app, principal: current_client, session: current_session)`
    で current 選択 + 切替候補を返す（JSON + 最小 HTML）。
  - `update`:
    `AcmeSwitcherAuthority.switch(surface: :app, principal: current_client, session: current_session, params: switcher_params)`。成功時 dashboard へ 303
    redirect（HTML）/ success JSON、`InvalidSwitch` 時 422 で show 再表示。params は
    `selectors_controller` と同形（`account_public_id` / `organization_public_id` /
    `organization_unit_public_id` / `avatar_public_id`、`collective_*`
    alias 許容）。作成・編集はしない。
- **削除**: orphan `current/organizations_controller.rb` と `app/views/acme/app/current/` 一式。

ownership / membership / availability は **DB
scope した find が権威的 gate**（session/JWT の値だけを信じない、というユーザ要件に合致）。`authorize!(record, to: :action?)`
を policy 層として併用。

### 3. Service — `app/services/`

- 新規 `acme_switcher_authority.rb`（`AcmeSwitcherAuthority`）:
  - `.current(surface:, principal:, session:)` — 現在の selection（session token の `selected_*`）+
    `selectable_candidates` を返す（show 用）。
  - `.switch(surface:, principal:, session:, params:)` —
    params の組合せを実 candidate に照合し、一致時のみ atomic に session token へ永続。不一致は
    `InvalidSwitch` を raise（→ 422）。検証失敗時は永続前に raise するので current
    context は一切変化しない。app は `requires_avatar: true`
    のため avatar 不在/不一致は candidate に一致せず拒否される（= app で current
    avatar 必須を担保）。
- 共有化リファクタ: `acme_selector_authority.rb`
  の candidate 解決・永続メソッド（`selectable_candidates` / `candidate_for_public_ids` /
  `persist_selection!` / `accounts` / `avatars_for` / `connection_owner`）を共有 mixin（例
  `app/services/concerns/acme_selectable_context.rb`）に抽出し、`AcmeSelectorAuthority` と
  `AcmeSwitcherAuthority` の両方で include。**selector の挙動は不変**
  （既存 selector テストが green のままであること）。

### 4. Policies — `app/policies/`

既存の deny-all stub（`AccountPolicy` / `AvatarPolicy` /
`OrganizationPolicy`）に、record の ownership /
membership を判定する最小ルールを補強（`ApplicationPolicy#owner?` 等を利用）。record
class解決（`Persona` → `PersonaPolicy` 等）は実装時に確認。policy が薄い間も **scoped
find が ownership の authoritative gate** であることを保証する（多層防御）。

### 5. Views — `app/views/acme/app/`（最小、`acme/shared/self_service/shell` を再利用）

- `accounts/`: `index` / `show` / `edit` を id ベースへ調整、`new` を追加。
- `avatars/`: `index` / `new` を追加、`show` / `edit` を維持。
- `organizations/`: 既存 `index` / `new` / `show` / `edit` を維持。
- `switchers/show.html.erb`: current context + 候補一覧の最小 HTML（編集・作成 UI は作らない）。
- 削除: `app/views/acme/app/current/`。
- Next.js 的な card/list UI は作らない。

---

## テスト

### Routing（`test/integration/routes/acme_route_contract_test.rb` を拡張）

- `resources :accounts` / `:organizations` / `:avatars` が期待 action に向くこと。
- `resource :switcher` が `acme/app/switchers#show` / `#update` に向くこと。
- app host で `/account` `/avatar` `/organization`（singular current）が
  **routable でない**こと（`assert_raises ActionController::RoutingError`）。

### 既存テスト更新（app cases のみ）

- `test/controllers/acme/self_service_routes_test.rb`: 削除した app の singular
  helper（`acme_app_account_url` / `acme_app_avatar_url` /
  `acme_app_current_organization_url`）を使う **app の assertion を除去/置換**。org / com
  cases は不変。

### 新規 controller test（`test/controllers/acme/app/`）

`accounts_controller_test.rb` / `organizations_controller_test.rb` / `avatars_controller_test.rb`:

- authentication: 未ログイン拒否、selector-only（bootstrap 済みだが未 select）拒否、full
  login 許可。
- authorization: 他人の id を show/edit/update 不可（not found / forbidden）。
- CRUD smoke: index/show/edit/update（organization/avatar は new/create も）。

### Switcher（`test/controllers/acme/app/switcher_controller_test.rb` を書き換え）

- `show`: current selection + 候補を返す。
- valid な account/org/avatar 組合せに切替でき、session token の `selected_*` が変わること。
- account↔org 不整合、org↔avatar 不整合、app で avatar 欠落 → 422、かつ selection 不変。
- 他人の account/org/avatar candidate を選べないこと。

### Fixtures / helpers

既存 `select_token!`（`AcmeSelectorBootstrapAuthority.call` + `AcmeSelectorAuthority.prepare`）、
`as_user_headers` /
`host_headers`（`test/support/auth_helpers.rb`）を踏襲。不整合テスト用に 2 人目の principal と追加 org/avatar を用意。

---

## Verification

1. `bin/rails routes -c acme/app/switchers` 等で helper 名と singular current 不在を確認。
2. 対象テスト:
   ```
   bin/rails test \
     test/integration/routes/acme_route_contract_test.rb \
     test/controllers/acme/app/accounts_controller_test.rb \
     test/controllers/acme/app/organizations_controller_test.rb \
     test/controllers/acme/app/avatars_controller_test.rb \
     test/controllers/acme/app/switcher_controller_test.rb \
     test/controllers/acme/self_service_routes_test.rb
   ```
3. selector 非回帰: `bin/rails test test/controllers/acme/app/selector_controller_test.rb`。
4. 広域: `bin/rails test test/controllers/acme`。

---

## 未解決リスク / 注意

- **Cross-surface 乖離**: app から singular current routes を除去するが、org /
  com は app-only 制約に従い維持する。結果として app ↔
  org/com で route 形状が乖離し、`self_service_routes_test` は app
  cases のみ変更する。将来 org/com も統合するなら別タスク。
- **Account /
  Avatar の new/create**: 実体の新規作成 domain ロジックは本タスク範囲外（最小 skeleton。既存
  `OrganizationsController#create` も redirect stub）。実際の account/avatar
  provisioning は bootstrap（`AcmeSelectorBootstrapAuthority`）が引き続き正路。
- **Selector 共有リファクタ**:
  login-critical な selector のロジックを mixin 抽出するため、selector テストの green 維持を必須条件とする。
- **Policy の record-class 解決**: `Persona` 等の policy が薄い場合でも、scoped
  find による ownership gate を authoritative とする。
