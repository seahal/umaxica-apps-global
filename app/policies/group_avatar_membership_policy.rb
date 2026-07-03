# typed: false
# frozen_string_literal: true

class GroupAvatarMembershipPolicy < ApplicationPolicy
  def create?
    user.is_a?(Client) && same_selected_group_account?
  end

  def update?
    user.is_a?(Client) && record.active? && same_selected_group_account?
  end

  def destroy?
    user.is_a?(Client) && record.active? && same_selected_group_account?
  end

  private

  def same_selected_group_account?
    group = record.respond_to?(:avatar_group) ? record.avatar_group : nil
    group.is_a?(AvatarGroup) &&
      group.account_surface == "app" &&
      group.account_public_id == Actor.selection.account_public_id
  end
end
