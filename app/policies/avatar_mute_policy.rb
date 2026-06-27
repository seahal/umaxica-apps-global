# typed: false
# frozen_string_literal: true

class AvatarMutePolicy < ApplicationPolicy
  def create?
    actor_avatar = user
    target_avatar = record&.muted_avatar
    actor_avatar.is_a?(Avatar) && target_avatar.is_a?(Avatar) && actor_avatar != target_avatar
  end

  def destroy?
    actor_avatar = user
    record.present? && actor_avatar.is_a?(Avatar) && record.muter_avatar_id == actor_avatar.id
  end
end
