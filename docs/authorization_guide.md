# 認可 (Authorization) 実装ガイド

## 概要

本アプリケーションの認可は **Action Policy** (`action_policy` gem) で実装する。Pundit は使用しない。

基本方針:

- 認可コンテキストは **Actor**（`Actor::Context`）。`ApplicationController` 系で
  `authorize :actor, through: :current_actor` として束ねる。
- すべてのポリシーは `ApplicationPolicy < ActionPolicy::Base` を継承し、**デフォルト全拒否 (deny-all
  / allowlist)**。各アクション述語を明示的に `true` にしない限り許可されない。
- 所有者判定・ロール判定・JWT スコープ判定・サーフェス（app/org/com）判定を `ApplicationPolicy`
  のヘルパとして提供する。

関連実装:

- ベース: `app/policies/application_policy.rb`
- ポリシー群: `app/policies/`（`ClientPolicy` / `OperatorPolicy` / `VisitorPolicy` ほか）
- コンテキスト: `app/models/actor.rb`、`app/controllers/concerns/actor_support.rb`
- 失敗ハンドリング: `app/controllers/concerns/authorization_audit.rb`

## 認可コンテキスト（Actor）

`ApplicationPolicy` は以下の 2 コンテキストを宣言する（`app/policies/application_policy.rb`）:

```ruby
class ApplicationPolicy < ActionPolicy::Base
  # Actor::Context が主コンテキスト。レガシーな `user` は省略時に actor から導出する。
  authorize :actor, optional: true
  authorize :user, optional: true

  def user
    @user || actor_resource
  end
  # ...
end
```

サーフェスごとの `ApplicationController` が actor を供給する（例:
`app/controllers/core/app/application_controller.rb`）:

```ruby
authorize :actor, through: :current_actor
```

`current_actor` は `Actor.context`（`ActiveSupport::CurrentAttributes`
ベース）を返す（`app/controllers/concerns/actor_support.rb`）。ポリシー内では:

- `actor` … `Actor::Context`
- `user` … `actor` から導出した実リソース（`Client` / `Operator` / `Visitor`）。未認証時は `nil`
- `record` … 認可対象レコード

## ApplicationPolicy のヘルパ

`app/policies/application_policy.rb` がポリシー内で使えるヘルパを提供する。

| メソッド                                                                      | 説明                                                                                                               |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `actor` / `user`                                                              | 認可コンテキスト / 導出された実リソース                                                                            |
| `record`                                                                      | 認可対象レコード                                                                                                   |
| `owner?`                                                                      | `user` が `record` の所有者か（Client→`user_id` / Operator→`staff_id` / Visitor→`visitor_id`、または同一リソース） |
| `operator?` / `manager?` / `editor?` / `contributor?` / `viewer?`             | 組織スコープ付きロール判定                                                                                         |
| `operator_or_manager?` / `can_edit?` / `can_view?` / `can_contribute?`        | 複合ロール判定                                                                                                     |
| `has_scope?(scope)`                                                           | JWT スコープ判定（`current_token` の `scp` クレーム由来）                                                          |
| `domain_app?` / `domain_org?` / `domain_com?` / `domain_permitted?(*domains)` | JWT `aud` クレームのサーフェス判定                                                                                 |
| `current_token`                                                               | `Actor.authz.token_claims`                                                                                         |

デフォルト述語（`index?` / `show?` / `create?` / `update?` / `destroy?`）はすべて `false`。
`edit?`→`update?`、`new?`→`create?` は `alias_rule` で対応付けられている。

## ポリシーの実装

`app/policies/client_policy.rb` の例:

```ruby
class ClientPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator) && operator_or_manager?
  end

  def show?
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def create?
    user.is_a?(Operator) && operator?
  end

  def update?
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def destroy?
    (owner? && user.is_a?(Client)) || (user.is_a?(Operator) && operator?)
  end

  # スコープ（一覧フィルタ）は relation_scope で定義する。
  relation_scope do |relation|
    if user.is_a?(Operator) && operator_or_manager?
      relation.all
    elsif user.is_a?(Client)
      relation.where(id: user.id)
    else
      relation.none
    end
  end
end
```

ポイント:

- アクター種別（`Client` / `Operator` / `Visitor`）を明示的に分岐する。
- 所有権は `owner?` で明示チェックする。
- スコープは Pundit の `Scope` クラスではなく Action Policy の `relation_scope` ブロックで定義する。

## コントローラでの利用

### アクション認可

`authorize!(record, to: :action?)` を呼ぶ。`before_action`
から使う場合はシンボルで渡せないため、名前付きラッパーメソッドにして `before_action`
に登録するのが本アプリの慣用パターン:

```ruby
class Sign::App::Settings::SessionsController < ...
  before_action :authorize_sessions!, only: %i(index)

  private

  def authorize_sessions!
    authorize!(ClientToken, to: :index?)
  end
end
```

レコードインスタンスを直接渡すこともできる（例: `authorize!(current_client, to: :show?)`）。

### スコープ適用

一覧取得は `authorized_scope` で `relation_scope` を適用する（例:
`app/controllers/sign/app/settings/passkeys_controller.rb`）:

```ruby
@passkeys = authorized_scope(current_client.client_passkeys).order(created_at: :desc)
```

## 認可失敗時の挙動

各サーフェスの `ApplicationController` が例外を捕捉する:

```ruby
rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
```

`handle_authorization_error`（`app/controllers/concerns/authorization_audit.rb`）の挙動:

- 失敗を監査ログに記録（`authorization.failure`
  イベント、監査レコード作成）。ログ処理自体の例外は握りつぶしてアプリを止めない。
- レスポンス:
  - HTML:
    `flash[:alert] = I18n.t("errors.messages.not_authorized")`（`この操作を行う権限がありません。`）の上で
    `safe_redirect_back_or_to(root_path)`。
  - JSON: `{ error: "Unauthorized" }` を `:forbidden`（403）で返す。

> 注: 認可と **ステップアップ認証** は別レイヤ。ステップアップは
> `Verification::Base#require_step_up!` と `step_up`
> DSL（`Verification::StepUpGuard`）で扱い、失敗時は 302 リダイレクト / 401 /
> 422 を返す。認可（ActionPolicy）の 403 とは別物。

## テスト

ポリシーは `test/policies/` 配下で単体テストする（Action
Policy のテストヘルパを利用）。アクターごとに許可 / 拒否 / 未認証 / 別ユーザ / 別スタッフのケースを網羅する。

```ruby
require "test_helper"

class ClientPolicyTest < ActiveSupport::TestCase
  test "operator manager can view the client list" do
    assert_predicate ClientPolicy.new(record, actor: operator_manager_context), :index?
  end

  test "anonymous actor cannot view the client list" do
    assert_not_predicate ClientPolicy.new(record, actor: anonymous_context), :index?
  end
end
```

（実際のコンテキスト生成は `test/policies/application_policy_actor_context_test.rb` 等を参照。）

## ベストプラクティス

1. **デフォルト全拒否**: `ApplicationPolicy` は allowlist。必要な述語のみ明示的に許可する。
2. **明示的な認可呼び出し**: コントローラで `authorize!` / `authorized_scope` を必ず呼ぶ。
3. **アクター種別と所有権を明示**: `user.is_a?(...)` と `owner?` を組み合わせる。
4. **コンテキストは Actor 経由**: コントローラのインスタンス変数に依存せず `actor` / `user` を使う。
5. **テストを書く**: 各ポリシーに許可 / 拒否 / 未認証 / 越境ケースのテストを追加する。

## トラブルシュート

### `ActionPolicy::Unauthorized` が発生する

- 当該アクションのポリシー述語が `false`
  を返している。ポリシーとアクター種別・所有権・ロールを確認する。
- 期待挙動なら問題なし（403 / リダイレクト）。誤りなら述語条件を見直す。

### ポリシーが見つからない

命名規約を確認する（モデル `Client` → `ClientPolicy` =
`app/policies/client_policy.rb`）。レコードを使わない認可は `authorize!(SomeClass, to: :action?)`
のようにクラスを渡す。

### コンテキストが取れない

`current_actor`（= `Actor.context`）が `set_current_actor`
で投入されているかを確認する（`app/controllers/concerns/actor_support.rb`、`BareController`
系はライフサイクルを意図的にバイパスする）。
