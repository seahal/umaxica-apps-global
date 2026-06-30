# typed: false
# frozen_string_literal: true

module ExternalSignIn
  # Resolves a verified NormalizedAuthResult to a pre-provisioned OperatorEntraIdentity.
  #
  # Raises IdentityNotFoundError if:
  # - No OperatorEntraIdentity exists for the (tenant_id, object_id) pair
  # - The found identity's status_id is not ACTIVE
  # - The identity's OrganizationEntraConnection status_id is not ACTIVE
  #
  # Never creates records. Sign-in fails loudly on miss — no JIT provisioning.
  class OrgEntraResolver
    def initialize(auth_result:)
      @auth_result = auth_result
    end

    def call
      identity = OperatorEntraIdentity
        .includes(:connection)
        .find_by(entra_tenant_id: auth_result.tenant_id, entra_object_id: auth_result.entra_object_id)

      raise IdentityNotFoundError,
            "no identity provisioned for (#{auth_result.tenant_id}, #{auth_result.entra_object_id})" if identity.nil?
      raise IdentityNotFoundError, "identity is not active" unless identity.status_id == OperatorEntraIdentityState::ACTIVE
      raise IdentityNotFoundError, "connection is not active" unless identity.connection.status_id == OrganizationEntraConnectionState::ACTIVE

      identity
    end

    private

    attr_reader :auth_result
  end
end
