# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Unmute < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_mute&.destroy
    end

    private

    def existing_mute
      actor_avatar.outgoing_mutes.find_by(muted_avatar_id: target_avatar.id)
    end
  end
end
