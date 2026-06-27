# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Mute < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot mute itself" if actor_avatar == target_avatar

      existing_mute || create_mute
    end

    private

    def existing_mute
      actor_avatar.outgoing_mutes.find_by(muted_avatar_id: target_avatar.id)
    end

    def create_mute
      actor_avatar.outgoing_mutes.create!(muted_avatar: target_avatar)
    end
  end
end
