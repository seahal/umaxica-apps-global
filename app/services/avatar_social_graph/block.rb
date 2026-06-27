# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Block < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot block itself" if actor_avatar == target_avatar

      block = existing_block || create_block
      terminate_follow(actor_avatar, target_avatar)
      terminate_follow(target_avatar, actor_avatar)
      block
    end

    private

    def existing_block
      actor_avatar.outgoing_blocks.find_by(blocked_avatar_id: target_avatar.id)
    end

    def create_block
      actor_avatar.outgoing_blocks.create!(blocked_avatar: target_avatar)
    end

    def terminate_follow(follower, followed)
      follower.outgoing_follows.where(followed_avatar_id: followed.id).destroy_all
    end
  end
end
