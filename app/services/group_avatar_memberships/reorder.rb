# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Reorder < ApplicationService
    def initialize(membership:, position:)
      super()
      @membership = membership
      @position = Integer(position)
    end

    def call
      raise ArgumentError, "membership is not active" unless membership.active?
      raise ArgumentError, "position must be non-negative" if position.negative?

      membership.update!(position: position)
      membership
    end

    private

    attr_reader :membership, :position
  end
end
