# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class EntraTenantContext < Data.define(:tenant_id, :object_identifier)
    UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    private_constant :UUID_FORMAT

    def initialize(tenant_id:, object_identifier:)
      raise ArgumentError, "tenant_id is invalid" unless tenant_id.to_s.match?(UUID_FORMAT)
      raise ArgumentError, "object_identifier is invalid" unless object_identifier.to_s.match?(UUID_FORMAT)

      super(tenant_id: tenant_id.dup.freeze, object_identifier: object_identifier.dup.freeze)
    end
  end
end
