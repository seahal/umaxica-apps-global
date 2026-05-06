# Authorization (AuthZ) Implementation Guide

## Overview

This application implements a Pundit-based authorization system. It uses a hybrid approach that
combines RBAC (Role-Based Access Control) and resource-based authorization.

## Role Definitions

Five role levels:

| Role        | Key           | Permissions                                                   |
| ----------- | ------------- | ------------------------------------------------------------- |
| Operator    | `admin`       | Full permissions, including user management and delete rights |
| Manager     | `manager`     | Content management, editing and deleting other users' posts   |
| Editor      | `editor`      | Create and edit all content, delete only their own posts      |
| Contributor | `contributor` | Create content, edit only their own posts                     |
| Viewer      | `viewer`      | Read-only                                                     |

## Usage in Controllers

### Basic authorization checks

```ruby
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  def show
    authorize @document # Check permissions through the policy
  end

  def create
    @document = Document.new(document_params)
    @document.user = current_user

    authorize @document

    if @document.save
      redirect_to @document, notice: "Created successfully"
    else
      render :new
    end
  end

  def update
    authorize @document

    if @document.update(document_params)
      redirect_to @document, notice: "Updated successfully"
    else
      render :edit
    end
  end

  def destroy
    authorize @document

    @document.destroy!
    redirect_to documents_path, notice: "Deleted successfully"
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end
end
```

### Filtering with scopes

```ruby
def index
  # Policy scopes filter automatically
  # - Operator/Manager: see all documents
  # - Others: see only their own documents
  @documents = policy_scope(Document)
end
```

### Conditional authorization

```ruby
def some_action
  @document = Document.find(params[:id])

  if policy(@document).update?
    # Handle the case where the user has update permission
  else
    # Handle the case where the user does not have permission
  end
end
```

## Using authorization in views

### AuthorizationHelper methods

#### 1. `authorized?` - action permission check

```erb
<% if authorized?(@document, :edit?) %>
  <%= link_to "Edit", edit_document_path(@document), class: "btn btn-primary" %>
<% end %>

<% if authorized?(@document, :destroy?) %>
  <%= link_to "Delete", document_path(@document), method: :delete,
      data: { confirm: "Are you sure?" }, class: "btn btn-danger" %>
<% end %>
```

#### 2. `has_role?` - role check

```erb
<% if has_role?("operator") %>
  <div class="admin-panel">
    <%= link_to "User Management", admin_users_path %>
    <%= link_to "System Settings", admin_settings_path %>
  </div>
<% end %>

<% if has_role?("editor", organization: @current_organization) %>
  <%= render "editor_tools" %>
<% end %>
```

#### 3. `has_any_role?` - multiple role check

```erb
<% if has_any_role?("operator", "manager") %>
  <%= render "management_dashboard" %>
<% end %>
```

#### 4. Convenience helper methods

```erb
<!-- Operator check -->
<% if admin? %>
  <%= render "admin_menu" %>
<% end %>

<!-- Manager or Operator -->
<% if admin_or_manager? %>
  <%= link_to "Manage Users", manage_users_path %>
<% end %>

<!-- Can edit -->
<% if can_edit? %>
  <%= render "edit_tools" %>
<% end %>

<!-- Can contribute -->
<% if can_contribute? %>
  <%= link_to "Create New", new_document_path %>
<% end %>
```

#### 5. Block syntax

```erb
<%= if_authorized @document, :edit? do %>
  <div class="edit-section">
    <%= render "edit_form" %>
  </div>
<% end %>

<%= if_has_role "operator" do %>
  <%= render "admin_controls" %>
<% end %>
```

## Creating policy classes

### Basic structure

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    # Organization members can view the list
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

### Helpful ApplicationPolicy methods

| Method              | Description                                          |
| ------------------- | ---------------------------------------------------- |
| `actor`             | Current User or Staff                                |
| `record`            | The record being authorized                          |
| `organization`      | Workspace automatically derived from the record      |
| `owner?`            | Whether the actor owns the record                    |
| `admin?`            | Whether the actor has the admin role                 |
| `manager?`          | Whether the actor has the manager role               |
| `editor?`           | Whether the actor has the editor role                |
| `contributor?`      | Whether the actor has the contributor role           |
| `viewer?`           | Whether the actor has the viewer role                |
| `admin_or_manager?` | Admin or manager                                     |
| `can_edit?`         | Edit permission (admin/manager/editor)               |
| `can_view?`         | View permission (all roles)                          |
| `can_contribute?`   | Create permission (admin/manager/editor/contributor) |

## Role management

### Assigning roles

```ruby
# Get organization and role
organization = Workspace.find_by(name: "My Organization")
admin_role = Role.find_by(key: "operator", organization: organization)

# Assign the role to a user
RoleAssignment.create!(user: user, role: admin_role)
```

### Checking roles

```ruby
user = User.find(params[:id])
organization = Workspace.first

# Check whether a specific role is present
user.has_role?("operator", organization: organization)
```
