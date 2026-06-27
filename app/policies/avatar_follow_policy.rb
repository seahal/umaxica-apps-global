# typed: false
# frozen_string_literal: true

class AvatarFollowPolicy < ApplicationPolicy
  def create?
    actor_avatar = user
    target_avatar = record&.followed_avatar
    return false unless actor_avatar.is_a?(Avatar) && target_avatar.is_a?(Avatar)
    return false if actor_avatar == target_avatar
    return false if actor_avatar.blocked_avatars.exists?(id: target_avatar.id)
    return false if target_avatar.blocked_avatars.exists?(id: actor_avatar.id)

    true
  end

  def destroy?
    actor_avatar = user
    record.present? && actor_avatar.is_a?(Avatar) && record.follower_avatar_id == actor_avatar.id
  end
end
