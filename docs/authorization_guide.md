# Authorization (AuthZ) Implementation Guide

## Overview

This application implements a **Pundit** based authorization system. \*\*RBAC (Role-Based Access We
use a hybrid approach that combines control) and resource-based authorization.

## role definition

5-level role hierarchy:

| Role        | Key           | Permission                                                          |
| ----------- | ------------- | ------------------------------------------------------------------- |
| Operator    | `admin`       | Full privileges (including user management and deletion privileges) |
| Manager     | `manager`     | Content management, editing/deleting other users' posts             |
| Editor      | `editor`      | You can create and edit all content, and only delete your own posts |
| Contributor | `contributor` | Content creation, you can only edit your own posts                  |
| Viewer      | `viewer`      | View only                                                           |

## Use with controller

### Basic authorization check

```ruby
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  def show
    authorize @document # Check permissions with policy
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

### Filtering using scopes

```ruby
def index
  # Automatically filter by policy scope
  # - Operator/Manager: View all documents
  # - Other: Show only your own documents
  @documents = policy_scope(Document)
end
```

### conditional authorization

```ruby
def some_action
  @document = Document.find(params[:id])

  if policy(@document).update?
    # Processing when you have update authority
  else
    # What to do if you don't have permission
  end
end
```

## Use in views

### AuthorizationHelper method

#### 1. `authorized?` - Action permission check

```erb
<% if authorized?(@document, :edit?) %>
  <%= link_to "Edit", edit_document_path(@document), class: "btn btn-primary" %>
<% end %>

<% if authorized?(@document, :destroy?) %>
  <%= link_to "Delete", document_path(@document), method: :delete,
      data: { confirm: "Are you sure?" }, class: "btn btn-danger" %>
<% end %>
```

#### 2. `has_role?` - Roll check

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

#### 3. `has_any_role?` - Multiple role check

```erb
<% if has_any_role?('operator', 'manager') %>
  <%= render 'management_dashboard' %>
<% end %>
```

#### 4. Useful shortcut methods

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

#### 5. block syntax

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

## Creating a policy class

### Basic structure

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

### ApplicationPolicy convenience methods

Helper methods available within policies:

| Method              | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| `actor`             | Current User/Staff                                             |
| `record`            | Records to be authorized                                       |
| `organization`      | Workspace (compatible name) automatically obtained from record |
| `owner?`            | Is the actor the owner of the record                           |
| `admin?`            | Have admin role                                                |
| `manager?`          | Have manager role                                              |
| `editor?`           | Have editor role                                               |
| `contributor?`      | Have contributor role                                          |
| `viewer?`           | Does it have viewer role                                       |
| `admin_or_manager?` | admin or manager                                               |
| `can_edit?`         | Editing authority (admin/manager/editor)                       |
| `can_view?`         | Viewing permissions (all roles)                                |
| `can_contribute?`   | Creation authority (admin/manager/editor/contributor)          |

## role management

### Role assignment

```ruby
# Get organization and role
organization = Workspace.find_by(name: "My Organization")
admin_role = Role.find_by(key: 'operator', organization: organization)

# Assign roles to users
RoleAssignment.create!(user: user, role: admin_role)
```

### Checking the role

```ruby
user = User.find(params[:id])
organization = Workspace.first

# Does it have a specific role?
user.has_role?('operator', organization: organization)

# Do you have any role?
user.has_any_role?('operator', 'manager', organization: organization)

# Do you have editing privileges?
user.can_edit?(organization: organization)

# Get all roles in an organization
user.roles_in(organization)
```

## audit log

Audit logs are automatically logged when authorization fails:

```ruby
# The log contains the following information:
# - actor_type: User or Staff
# - actor_id: Actor's ID
# - action: Action name (show, edit, etc)
# - controller: Controller name
# - policy: Policy class name
# - query: Checked method name
# - record_type: record type
# - record_id: record ID
# - ip_address: Request source IP address
# - timestamp: timestamp
```

The audit log is:

1. Log as a warning in **Rails.logger**
2. Saved in **UserIdentityAudit** or **StaffIdentityAudit** table

## test

### Testing the policy

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

## best practices

1. **Always whitelist method**: ApplicationPolicy denies everything by default
2. **Explicit permission check**: Remember to call `authorize` in your controller
3. **Using scope**: Automatic filtering with `policy_scope`
4. **Create tests**: Write tests for each policy
5. **Consideration of organizational scope**: Be aware of the organization in a multi-tenant
   environment
6. **Check Audit Log**: Regularly check for unauthorized access attempts

## troubleshooting

### `ActionPolicy::Unauthorized` occurs

Check if you forgot to add `authorize` to your controller:

```ruby
def show
  @document = Document.find(params[:id])
  authorize @document # <- add this
end
```

### Policy not found

Check that the policy file exists and has the correct naming convention:

- Model: `Document`
- Policy: `DocumentPolicy` (`app/policies/document_policy.rb`)

### role doesn't work

1. Check if role is seeded correctly
2. Check if RoleAssignment has been created
3. Check if the organization scope is correct

```ruby
# Debugging code
user.roles.pluck(:key)  # => ["operator", "editor"]
user.has_role?('operator', organization: org)  # => true/false
```

## summary

With this AuthZ implementation:

- ✅ Flexible role-based permission management
- ✅ Fine-grained resource-level control
- ✅ Automatic audit log of authorization failures
- ✅ Easy permission check in view
- ✅ Testable design

Please refer to each policy file and ApplicationPolicy for details.
