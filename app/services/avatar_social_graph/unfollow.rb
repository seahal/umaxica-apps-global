# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Unfollow < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_follow&.destroy
    end

    private

    def existing_follow
      actor_avatar.outgoing_follows.find_by(followed_avatar_id: target_avatar.id)
    end
  end
end
