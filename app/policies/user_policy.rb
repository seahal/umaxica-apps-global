# typed: false
# frozen_string_literal: true

# Authorization policy for User resource management
# Controls who can view, create, update, and delete users
class UserPolicy < ApplicationPolicy
  def index?
    # Only staff managers and above can view user list
    actor.is_a?(Staff) && operator_or_manager?
  end

  def show?
    # Users can see their own profile, staff managers can see any user
    owner? || (actor.is_a?(Staff) && operator_or_manager?)
  end

  def create?
    # Public registration is handled separately
    # Only staff operators can directly create users
    actor.is_a?(Staff) && operator?
  end

  def update?
    # Users can update their own profile, staff managers can update any user
    owner? || (actor.is_a?(Staff) && operator_or_manager?)
  end

  def destroy?
    # Only staff operators can delete users (or users can delete themselves via withdrawal)
    (owner? && actor.is_a?(User)) || (actor.is_a?(Staff) && operator?)
  end

  relation_scope do |relation|
    if actor.is_a?(Staff) && operator_or_manager?
      # Staff managers see all users
      relation.all
    elsif actor.is_a?(User)
      # Users see only themselves
      relation.where(id: actor.id)
    else
      # Unauthenticated users see nothing
      relation.none
    end
  end
end
