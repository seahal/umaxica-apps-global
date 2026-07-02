# typed: false
# frozen_string_literal: true

class AvatarPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  def show?
    owns_avatar?
  end

  def create?
    user.is_a?(Client)
  end

  def update?
    owns_avatar?
  end

  relation_scope do |relation|
    next relation.none unless user.is_a?(Client)

    relation.joins(:avatar_assignments).where(avatar_assignments: { user_id: user.id })
  end

  private

  def owns_avatar?
    user.is_a?(Client) &&
      record.is_a?(Avatar) &&
      record.avatar_assignments.where(user_id: user.id).exists?
  end
end
