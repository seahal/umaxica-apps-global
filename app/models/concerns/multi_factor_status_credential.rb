# typed: false
# frozen_string_literal: true

module MultiFactorStatusCredential
  extend ActiveSupport::Concern

  OWNER_ASSOCIATIONS = Concurrent::Map.new

  included { after_commit :refresh_owner_multi_factor_status }

  class_methods do
    def multi_factor_status_owner(association_name)
      OWNER_ASSOCIATIONS[self] = association_name
    end

    def multi_factor_status_owner_association
      OWNER_ASSOCIATIONS.fetch(self)
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
