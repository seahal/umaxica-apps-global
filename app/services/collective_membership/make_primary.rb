# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class MakePrimary < ApplicationService
    def initialize(membership:)
      super()
      @membership = membership
    end

    def call
      raise InactiveMembership, "membership is not active" unless membership.active?

      membership.class.transaction do
        membership.class.primary_active
          .where(membership.class.account_foreign_key => membership.public_send(membership.class.account_foreign_key))
          .where.not(id: membership.id)
          .find_each { |active_primary| active_primary.update!(primary: false) }
        membership.update!(primary: true)
      end
      membership
    end

    private

    attr_reader :membership
  end
end
