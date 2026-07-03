# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class Suspend < ApplicationService
    def initialize(membership:)
      super()
      @membership = membership
    end

    def call
      raise InactiveMembership, "membership is revoked" if membership.revoked?

      membership.update!(membership_state_id: state_class::SUSPENDED, primary: false)
      membership
    end

    private

    attr_reader :membership

    def state_class = membership.class.reflect_on_association(:membership_state).klass
  end
end
