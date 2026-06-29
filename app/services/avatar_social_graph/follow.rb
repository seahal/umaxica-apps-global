# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Follow < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot follow itself" if actor_avatar == target_avatar
      raise BlockedError, "follow blocked by target avatar" if blocked_by_target?
      raise BlockedError, "follow blocked by actor avatar" if blocked_by_actor?

      existing_follow || create_follow
    end

    private

    def blocked_by_target?
      target_avatar.outgoing_blocks.exists?(blocked_avatar_id: actor_avatar.id)
    end

    def blocked_by_actor?
      actor_avatar.outgoing_blocks.exists?(blocked_avatar_id: target_avatar.id)
    end

    def existing_follow
      actor_avatar.outgoing_follows.find_by(followed_avatar_id: target_avatar.id)
    end

    def create_follow
      actor_avatar.outgoing_follows.create!(followed_avatar: target_avatar)
    end
  end
end
