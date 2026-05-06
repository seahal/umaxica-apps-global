# Authorization (AuthZ) Implementation Guide

## Overview

このアプリケーションは、**Pundit**ベースの認可システムを実装しています。 **RBAC（Role-Based Access
Control）**と**リソースベース認可**を組み合わせたハイブリッドアプローチを採用しています。

## ロール定義

5段階のロールヒエラルキー：

| Role        | Key           | 権限                                             |
| ----------- | ------------- | ------------------------------------------------ |
| Operator    | `admin`       | 全権限（ユーザー管理、削除権限含む）             |
| Manager     | `manager`     | コンテンツ管理、他ユーザーの投稿編集・削除       |
| Editor      | `editor`      | 全コンテンツの作成・編集、自分の投稿のみ削除可能 |
| Contributor | `contributor` | コンテンツ作成、自分の投稿のみ編集可能           |
| Viewer      | `viewer`      | 閲覧のみ                                         |

## コントローラーでの使用

### 基本的な認可チェック

```ruby
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  def show
    authorize @document  # ポリシーで権限チェック
  end

  def create
    @document = Document.new(document_params)
    @document.user = current_user

    authorize @document

    if @document.save
      redirect_to @document, notice: 'Created successfully'
    else
      render :new
    end
  end

  def update
    authorize @document

    if @document.update(document_params)
      redirect_to @document, notice: 'Updated successfully'
    else
      render :edit
    end
  end

  def destroy
    authorize @document

    @document.destroy!
    redirect_to documents_path, notice: 'Deleted successfully'
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end
end
```

### スコープを使ったフィルタリング

```ruby
def index
  # ポリシースコープで自動的にフィルタリング
  # - Operator/Manager: 全ドキュメント表示
  # - その他: 自分のドキュメントのみ表示
  @documents = policy_scope(Document)
end
```

### 条件付き認可

```ruby
def some_action
  @document = Document.find(params[:id])

  if policy(@document).update?
    # 更新権限がある場合の処理
  else
    # 権限がない場合の処理
  end
end
```

## ビューでの使用

### AuthorizationHelper メソッド

#### 1. `authorized?` - アクション権限チェック

```erb
<% if authorized?(@document, :edit?) %>
  <%= link_to "Edit", edit_document_path(@document), class: "btn btn-primary" %>
<% end %>

<% if authorized?(@document, :destroy?) %>
  <%= link_to "Delete", document_path(@document), method: :delete,
      data: { confirm: "Are you sure?" }, class: "btn btn-danger" %>
<% end %>
```

#### 2. `has_role?` - ロールチェック

```erb
<% if has_role?('operator') %>
  <div class="admin-panel">
    <%= link_to "User Management", admin_users_path %>
    <%= link_to "System Settings", admin_settings_path %>
  </div>
<% end %>

<% if has_role?('editor', organization: @current_organization) %>
  <%= render 'editor_tools' %>
<% end %>
```

#### 3. `has_any_role?` - 複数ロールチェック

```erb
<% if has_any_role?('operator', 'manager') %>
  <%= render 'management_dashboard' %>
<% end %>
```

#### 4. 便利なショートカットメソッド

```erb
<!-- Operator check -->
<% if admin? %>
  <%= render 'admin_menu' %>
<% end %>

<!-- Manager or Operator -->
<% if admin_or_manager? %>
  <%= link_to "Manage Users", manage_users_path %>
<% end %>

<!-- Can edit -->
<% if can_edit? %>
  <%= render 'edit_tools' %>
<% end %>

<!-- Can contribute -->
<% if can_contribute? %>
  <%= link_to "Create New", new_document_path %>
<% end %>
```

#### 5. ブロック構文

```erb
<%= if_authorized @document, :edit? do %>
  <div class="edit-section">
    <%= render 'edit_form' %>
  </div>
<% end %>

<%= if_has_role 'operator' do %>
  <%= render 'admin_controls' %>
<% end %>
```

## ポリシークラスの作成

### 基本構造

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    # Organization members can view list
    can_view?
  end

  def show?
    # Owner or viewer role
    owner? || can_view?
  end

  def create?
    # Contributors and above
    can_contribute?
  end

  def update?
    # Owner or editors and above
    owner? || can_edit?
  end

  def destroy?
    # Owner or managers and above
    owner? || admin_or_manager?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin_or_manager?
        scope.all
      elsif actor
        scope.where(user_id: actor.id)
      else
        scope.none
      end
    end
  end
end
```

### ApplicationPolicy の便利メソッド

ポリシー内で使用可能なヘルパーメソッド：

| メソッド            | 説明                                         |
| ------------------- | -------------------------------------------- |
| `actor`             | 現在のUser/Staff                             |
| `record`            | 認可対象のレコード                           |
| `organization`      | recordから自動取得されたWorkspace（互換名）  |
| `owner?`            | アクターがレコードの所有者か                 |
| `admin?`            | adminロールを持つか                          |
| `manager?`          | managerロールを持つか                        |
| `editor?`           | editorロールを持つか                         |
| `contributor?`      | contributorロールを持つか                    |
| `viewer?`           | viewerロールを持つか                         |
| `admin_or_manager?` | admin または manager                         |
| `can_edit?`         | 編集権限（admin/manager/editor）             |
| `can_view?`         | 閲覧権限（全ロール）                         |
| `can_contribute?`   | 作成権限（admin/manager/editor/contributor） |

## ロール管理

### ロールの割り当て

```ruby
# 組織とロールを取得
organization = Workspace.find_by(name: "My Organization")
admin_role = Role.find_by(key: 'operator', organization: organization)

# ユーザーにロールを割り当て
RoleAssignment.create!(user: user, role: admin_role)
```

### ロールのチェック

```ruby
user = User.find(params[:id])
organization = Workspace.first

# 特定のロールを持つか
user.has_role?('operator', organization: organization)

# いずれかのロールを持つか
user.has_any_role?('operator', 'manager', organization: organization)

# 編集権限があるか
user.can_edit?(organization: organization)

# 組織内の全ロールを取得
user.roles_in(organization)
```

## 監査ログ

認可失敗時には自動的に監査ログが記録されます：

```ruby
# ログには以下の情報が含まれます：
# - actor_type: User または Staff
# - actor_id: アクターのID
# - action: アクション名（show, edit, etc）
# - controller: コントローラー名
# - policy: ポリシークラス名
# - query: チェックしたメソッド名
# - record_type: レコードの型
# - record_id: レコードのID
# - ip_address: リクエスト元IPアドレス
# - timestamp: タイムスタンプ
```

監査ログは：

1. **Rails.logger** に警告として記録
2. **UserIdentityAudit** または **StaffIdentityAudit** テーブルに保存

## テスト

### ポリシーのテスト

```ruby
require 'test_helper'

class DocumentPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = Workspace.create!(name: "Test Org")
    @admin_role = Role.create!(key: "operator", organization: @organization)
    @viewer_role = Role.create!(key: "viewer", organization: @organization)

    @admin = users(:one)
    @viewer = users(:two)

    RoleAssignment.create!(user: @admin, role: @admin_role)
    RoleAssignment.create!(user: @viewer, role: @viewer_role)

    @document = Document.new(user_id: users(:three).id)
  end

  test "admin can destroy documents" do
    policy = DocumentPolicy.new(@admin, @document)
    assert policy.destroy?
  end

  test "viewer cannot destroy documents" do
    policy = DocumentPolicy.new(@viewer, @document)
    assert_not policy.destroy?
  end
end
```

## ベストプラクティス

1. **常にホワイトリスト方式**: ApplicationPolicyはデフォルトで全て拒否
2. **明示的な権限チェック**: コントローラーで`authorize`を忘れずに呼ぶ
3. **スコープの活用**: `policy_scope`で自動フィルタリング
4. **テストの作成**: 各ポリシーに対してテストを書く
5. **組織スコープの考慮**: マルチテナント環境では組織を意識する
6. **監査ログの確認**: 不正アクセス試行を定期的にチェック

## トラブルシューティング

### `ActionPolicy::Unauthorized`が発生する

コントローラーに`authorize`を追加し忘れていないか確認：

```ruby
def show
  @document = Document.find(params[:id])
  authorize @document  # <- これを追加
end
```

### ポリシーが見つからない

ポリシーファイルが存在し、正しい命名規則になっているか確認：

- モデル: `Document`
- ポリシー: `DocumentPolicy`（`app/policies/document_policy.rb`）

### ロールが機能しない

1. ロールが正しくシードされているか確認
2. RoleAssignmentが作成されているか確認
3. 組織スコープが正しいか確認

```ruby
# デバッグ用コード
user.roles.pluck(:key)  # => ["operator", "editor"]
user.has_role?('operator', organization: org)  # => true/false
```

## まとめ

このAuthZ実装により：

- ✅ 柔軟なロールベース権限管理
- ✅ リソースレベルの細かい制御
- ✅ 認可失敗の自動監査ログ
- ✅ ビューでの簡単な権限チェック
- ✅ テスト可能な設計

詳細は各ポリシーファイルとApplicationPolicyを参照してください。
