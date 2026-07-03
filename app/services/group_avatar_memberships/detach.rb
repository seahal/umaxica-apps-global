# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Detach < ApplicationService
    def initialize(membership:)
      super()
      @membership = membership
    end

    def call
      return membership unless membership.active?

      membership.update!(state: "removed", removed_at: Time.current)
      membership
    end

    private

    attr_reader :membership
  end
end
