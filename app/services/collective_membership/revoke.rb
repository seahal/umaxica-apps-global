# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class Revoke < ApplicationService
    def initialize(membership:, revoked_by: nil, reason_id: nil)
      super()
      @membership = membership
      @revoked_by = revoked_by
      @reason_id = reason_id
    end

    def call
      return membership if membership.revoked?

      membership.update!(
        :membership_state_id => state_class::REVOKED,
        :revoked_at => Time.current,
        revoked_by_key => revoked_by,
        :revoke_reason_id => reason_id || reason_class::MANUAL,
        :primary => false,
      )
      membership
    end

    private

    attr_reader :membership, :revoked_by, :reason_id

    def state_class = membership.class.reflect_on_association(:membership_state).klass

    def reason_class = membership.class.reflect_on_association(:revoke_reason).klass

    def revoked_by_key = :"revoked_by_#{membership.class.account_association_name}"
  end
end
