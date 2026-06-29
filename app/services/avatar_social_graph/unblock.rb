# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Unblock < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_block&.destroy
    end

    private

    def existing_block
      actor_avatar.outgoing_blocks.find_by(blocked_avatar_id: target_avatar.id)
    end
  end
end
