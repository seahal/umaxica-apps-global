# typed: false
# frozen_string_literal: true

module MultiFactorStatusCredential
  extend ActiveSupport::Concern

  included do
    class_attribute :multi_factor_status_owner_association, instance_accessor: false
    after_commit :refresh_owner_multi_factor_status
  end

  class_methods do
    def multi_factor_status_owner(association_name)
      self.multi_factor_status_owner_association = association_name
    end
  end

  private

  def refresh_owner_multi_factor_status
    owner = public_send(self.class.multi_factor_status_owner_association)
    return unless owner&.respond_to?(:refresh_multi_factor_status!)
    return if owner.destroyed?

    operation = -> { owner.refresh_multi_factor_status! }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end
end
