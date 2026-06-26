# プラン: Acme app surface — Account / Organization / Avatar CRUD + Switcher 実装検証

## Context

Acme app surface に Account / Organization / Avatar の管理 route と、ログイン後の current
context 切り替え Switcher を Rails way で実装・検証することが目的。

repository を調査した結果、**今回の要件はすでに全て実装済み**であることが判明した。routes・controllers・service・views・tests がすべて存在し、テストも全パスしている。

本プランは現状の実装を検証し、要件との対照を記録するためのものである。追加実装は不要。

---

## 実装状況の確認結果

### Routes (`config/routes/acme.rb`, 行 78–174)

```ruby
# app surface のみ（com/org は別ブロック）
resource  :selector, only: %i(show update)           # ログイン前ceremony (PreAccess)
resource  :switcher, only: %i(show update)           # ログイン後context切り替え (FullAccess)

resources :accounts,      only: %i(index new create show edit update)
resources :organizations, only: %i(index new create show edit update) do
  resources :memberships, only: %i(index new create edit update destroy), module: :organizations
end
resources :avatars, only: %i(index new create show edit update)
```

- `resource :account / :organization / :avatar` は **app
  surface に存在しない**（行 164–166 のコメントで明示）
- com/org surface に `resource :account / :organization`
  が存在するが、これは別 constraints ブロックで管理されており app surface とは無関係

### Controllers

| ファイル                               | 親クラス                          | 概要                                                    |
| -------------------------------------- | --------------------------------- | ------------------------------------------------------- |
| `acme/app/accounts_controller.rb`      | `Acme::App::FullAccessController` | Persona CRUD。`AcmeSwitcherAuthority` で ownership gate |
| `acme/app/organizations_controller.rb` | `Acme::App::FullAccessController` | Enterprise CRUD。membership-scoped access               |
| `acme/app/avatars_controller.rb`       | `Acme::App::FullAccessController` | Avatar CRUD。assignment-scoped access                   |
| `acme/app/switchers_controller.rb`     | `Acme::App::FullAccessController` | current context 表示・切り替えのみ。作成/編集なし       |

### Controller 継承階層（3 段）

```
ActionController::Base
  └── Acme::App::ApplicationController  (AUTHENTICATION_MODE = :deny_all)
        └── Acme::App::PreAccessController  (:private, authenticate_client!)
              └── Acme::App::FullAccessController  (:private + require_selected_actor_context!)
```

すべての対象 controller が `FullAccessController` を継承しており、full login guard が確立済み。

### Service Layer

- `AcmeSwitcherAuthority` (`app/services/acme_switcher_authority.rb`)
  - `current`: 現在の selection + 候補一覧を返す
  - `switch(params)`: `candidate_for_public_ids` で全3要素を一括検証し、成功時のみ
    `persist_selection!` を呼ぶ（atomic）
  - 失敗時は `InvalidSwitch` を raise → current context は一切変更されない
  - `available_accounts / available_organizations / available_avatars / find_*`: CRUD
    controller の ownership gate に使用

- `AcmeSelectableContext` mixin が `candidate_for_public_ids` と `persist_selection!` を提供

### Views

```
app/views/acme/app/
  accounts/{index,show,new,edit}.html.erb
  organizations/{index,show,new,edit}.html.erb
  avatars/{index,show,new,edit}.html.erb
  switchers/show.html.erb
```

手動確認可能な最小 HTML が全 action に揃っている。

---

## テスト結果

```
bin/rails test \
  test/controllers/acme/app/switcher_controller_test.rb \
  test/controllers/acme/app/accounts_controller_test.rb \
  test/controllers/acme/app/organizations_controller_test.rb \
  test/controllers/acme/app/avatars_controller_test.rb

32 runs, 74 assertions, 0 failures, 0 errors, 0 skips
```

### テストカバレッジ対照

| 要件                                                                         | カバー状況                                             |
| ---------------------------------------------------------------------------- | ------------------------------------------------------ |
| 未ログインで accounts/organizations/avatars に入れない                       | ✅ 各 controller test                                  |
| selector-only (partial ceremony) 状態で入れない                              | ✅ 各 controller test                                  |
| full login 済みなら入れる                                                    | ✅ 各 controller test                                  |
| 他人の account を show/edit/update できない                                  | ✅ accounts_controller_test                            |
| 他人の organization を show/edit/update できない                             | ✅ organizations_controller_test                       |
| 他人の avatar を show/edit/update できない                                   | ✅ avatars_controller_test                             |
| switcher で他人の account/organization/avatar を選べない                     | ✅ switcher_controller_test (invalid params → 422)     |
| valid な context に切り替えできる                                            | ✅ switcher_controller_test                            |
| invalid update 後に current context が変化しない                             | ✅ switcher_controller_test                            |
| HTML redirect / JSON response の両対応                                       | ✅ switcher_controller_test                            |
| account/organization/avatar CRUD smoke                                       | ✅ 各 controller test                                  |
| `/account`, `/organization`, `/avatar` の singular current routes がないこと | ✅ routes ファイルで明示的に不在 (行 164–166 コメント) |
| `resource :switcher` が `switchers#show/update` に向く                       | ✅ `bin/rails routes` で確認済み                       |

---

## ADR との整合確認

- **`adr/identity-authority-boundary.md`**:
  Acme が Account/Session/Token 権威。Sign には Account ライフサイクルを置かない → 今回の実装はすべて Acme
  app surface。✅
- **`adr/sign-credential-gateway-surface.md`**: Sign は credential
  ceremony のみ。Account/Organization/Avatar 管理なし → 今回の routes は Sign 側に置いていない。✅
- **`adr/surface-account-collective-model-naming.md`**: app surface は `Client` → `Persona`
  (account) → `Enterprise` (collective)。Controller で `current_client` / `AcmeSwitcherAuthority`
  を使用。✅
- **`adr/app-actor-client-naming.md`**: app surface actor は `Client`。controller で
  `authenticate_client!` / `current_client` を使用。✅
- **`adr/actor-current-facade.md`**: `Actor` は current context
  facade。controller は pipeline 経由で context を install し、`FullAccessController` が
  `require_selected_actor_context!` を enforce。✅

---

## 完了条件の対照

| 完了条件                                                        | 状態                                   |
| --------------------------------------------------------------- | -------------------------------------- |
| Rails way の plural resources + singular switcher で route 整理 | ✅ 実装済み                            |
| controller は plural naming                                     | ✅ SwitchersController 含む全て plural |
| `/switcher` は current context 表示・変更のみ                   | ✅ show/update のみ                    |
| `/accounts`, `/organizations`, `/avatars` は実体 CRUD           | ✅ index/new/create/show/edit/update   |
| full login guard                                                | ✅ FullAccessController 継承           |
| unauthorized access が拒否される                                | ✅ ownership gate で 404               |
| invalid switch が atomic に拒否される                           | ✅ AcmeSwitcherAuthority#switch        |
| tests が追加され実行結果が報告されている                        | ✅ 32 runs, 0 failures                 |

---

## 追加実装は不要

今回の要件はすべて実装・テスト済みであり、テストもパスしている。実装作業なし。このプランはレビュー・記録用として保存する。
