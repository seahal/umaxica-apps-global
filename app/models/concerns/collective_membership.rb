# typed: false
# frozen_string_literal: true

module CollectiveMembership
  extend ActiveSupport::Concern

  included do
    self.belongs_to_required_by_default = false

    validates :membership_kind, :membership_state, presence: true
    validate :unit_must_belong_to_same_collective
    validate :only_one_active_primary_membership
  end

  CONFIG_REGISTRY = {}
  private_constant :CONFIG_REGISTRY

  private

  def unit_must_belong_to_same_collective
    unit = public_send(self.class.unit_association_name)
    return if unit.blank?

    collective_id = public_send(self.class.collective_foreign_key)
    unit_collective_id = unit.public_send(self.class.collective_foreign_key)
    return if collective_id == unit_collective_id

    errors.add(self.class.unit_association_name, :invalid)
  end

  def only_one_active_primary_membership
    return unless self[:primary]
    return if revoked_at.present? || ends_at.present?

    account_id = public_send(self.class.account_foreign_key)
    return if account_id.blank?

    duplicate = self.class
      .where(self.class.account_foreign_key => account_id, :primary => true, :revoked_at => nil, :ends_at => nil)
      .where.not(id:)
      .exists?
    errors.add(:primary, :taken) if duplicate
  end

  class_methods do
    def collective_membership_config(account_foreign_key:, collective_foreign_key:, unit_association_name:)
      CONFIG_REGISTRY[self] = {
        account_foreign_key: account_foreign_key,
        collective_foreign_key: collective_foreign_key,
        unit_association_name: unit_association_name,
      }
    end

    def account_foreign_key
      CONFIG_REGISTRY.fetch(self)[:account_foreign_key]
    end

    def collective_foreign_key
      CONFIG_REGISTRY.fetch(self)[:collective_foreign_key]
    end

    def unit_association_name
      CONFIG_REGISTRY.fetch(self)[:unit_association_name]
    end
  end
end
