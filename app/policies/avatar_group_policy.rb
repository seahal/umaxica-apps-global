# typed: false
# frozen_string_literal: true

class AvatarGroupPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  def show?
    same_selected_account?
  end

  def create?
    user.is_a?(Client)
  end

  def update?
    same_selected_account? && record.active?
  end

  def destroy?
    same_selected_account? && record.active?
  end

  private

  def same_selected_account?
    user.is_a?(Client) &&
      record.is_a?(AvatarGroup) &&
      record.account_surface == "app" &&
      record.account_public_id == Actor.selection.account_public_id
  end
end
