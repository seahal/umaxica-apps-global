# typed: false
# frozen_string_literal: true

module CollectiveMembership
  class Grant < ApplicationService
    def initialize(account:, collective:, unit:, kind_id:, primary: false, granted_by: nil)
      super()
      @account = account
      @collective = collective
      @unit = unit
      @kind_id = kind_id
      @primary = primary
      @granted_by = granted_by
    end

    def call
      membership_class.transaction do
        raise DuplicateActiveMembership, "duplicate active membership" if duplicate_active_membership?
        raise DuplicateActivePrimary, "duplicate active primary membership" if primary && duplicate_primary?
        raise InvalidUnitTransfer, "unit does not belong to collective" unless same_collective?

        membership_class.create!(
          account_key => account,
          collective_key => collective,
          unit_key => unit,
          :membership_kind_id => kind_id,
          :membership_state_id => state_class::ACTIVE,
          :primary => primary,
          :metadata => {},
          :starts_at => Time.current,
          granted_by_key => granted_by,
        )
      end
    end

    private

    attr_reader :account, :collective, :unit, :kind_id, :primary, :granted_by

    def membership_class = account.memberships.klass

    def account_key = membership_class.account_association_name

    def collective_key = membership_class.collective_association_name

    def unit_key = membership_class.unit_association_name

    def state_class = membership_class.reflect_on_association(:membership_state).klass

    def granted_by_key = :"granted_by_#{account_key}"

    def duplicate_active_membership?
      membership_class.active.exists?(
        membership_class.account_foreign_key => account.id,
        membership_class.collective_foreign_key => collective.id,
      )
    end

    def duplicate_primary?
      membership_class.primary_active.exists?(membership_class.account_foreign_key => account.id)
    end

    def same_collective?
      unit.public_send(membership_class.collective_foreign_key) == collective.id
    end
  end
end
