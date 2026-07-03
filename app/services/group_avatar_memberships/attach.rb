# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Attach < ApplicationService
    def initialize(group:, avatar:, role: "member", position: nil)
      super()
      @group = group
      @avatar = avatar
      @role = role
      @position = position
    end

    def call
      raise ArgumentError, "group is not active" unless group.active?
      raise ArgumentError, "avatar is not active" unless active_avatar?

      GroupAvatarMembership.create!(
        avatar_group: group,
        avatar: avatar,
        role: role,
        position: position || next_position,
        state: "active",
      )
    end

    private

    attr_reader :group, :avatar, :role, :position

    def active_avatar?
      avatar.lifecycle_state&.key == "active" && avatar.discarded_at.future? && avatar.purged_at.future?
    end

    def next_position
      group.group_avatar_memberships.active.maximum(:position).to_i + 1
    end
  end
end
