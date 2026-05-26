# typed: false
# frozen_string_literal: true

# Shared account interface for surface-local account implementations.
module Account
  extend ActiveSupport::Concern

  include ::PublicId

  included do
    validates :status_id, numericality: { only_integer: true }, if: -> { has_attribute?(:status_id) }
  end

  def memberships
    public_send(self.class.membership_association_name)
  end

  def current_memberships
    memberships
      .includes(*self.class.membership_context_association_names)
      .active
      .primary_first
  end

  def primary_membership
    memberships
      .includes(*self.class.membership_context_association_names)
      .primary_active
      .first
  end

  def current_membership
    primary_membership || current_memberships.first
  end

  def current_collective
    current_membership&.collective
  end

  def current_collective_unit
    current_membership&.collective_unit
  end

  class_methods do
    def membership_association_name
      membership_association&.name ||
        raise(NotImplementedError, "#{name} does not define a collective membership association")
    end

    def membership_context_association_names
      membership_class = membership_association.klass
      [membership_class.collective_association_name, membership_class.unit_association_name]
    end

    private

    def membership_association
      reflect_on_all_associations(:has_many).find do |association|
        association.klass.included_modules.include?(CollectiveMembership)
      end
    end
  end
end
