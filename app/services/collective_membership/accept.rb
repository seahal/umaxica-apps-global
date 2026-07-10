# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class Accept < ApplicationService
    def initialize(membership:, approved_by: nil)
      super()
      @membership = membership
      @approved_by = approved_by
    end

    def call
      membership.update!(
        :membership_state_id => state_class::ACTIVE,
        approved_by_key => approved_by,
        :starts_at => membership.starts_at || Time.current,
      )
      membership
    end

    private

    attr_reader :membership, :approved_by

    def state_class = membership.class.reflect_on_association(:membership_state).klass

    def approved_by_key = :"approved_by_#{membership.class.account_association_name}"
  end
end
