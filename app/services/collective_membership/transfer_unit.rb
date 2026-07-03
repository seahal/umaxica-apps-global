# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class TransferUnit < ApplicationService
    def initialize(membership:, unit:)
      super()
      @membership = membership
      @unit = unit
    end

    def call
      raise InactiveMembership, "membership is not active" unless membership.active?
      raise InvalidUnitTransfer, "unit does not belong to same collective" unless same_collective?

      membership.update!(membership.class.unit_association_name => unit)
      membership
    end

    private

    attr_reader :membership, :unit

    def same_collective?
      unit.public_send(membership.class.collective_foreign_key) ==
        membership.public_send(membership.class.collective_foreign_key)
    end
  end
end
