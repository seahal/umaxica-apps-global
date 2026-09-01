# typed: false
# frozen_string_literal: true

module ExternalSignIn
  # Resolves a verified Entra tenant context to a pre-provisioned
  # OperatorEntraIdentity.
  #
  # The lookup key is (tid, oid) and nothing else: `iss` and `sub` are audit
  # evidence, and email/UPN/preferred_username are mutable in Entra and are
  # never stored or consulted (adr/org-entra-id-sign-in-boundary.md).
  #
  # Raises IdentityNotFoundError if:
  # - No OperatorEntraIdentity exists for the (tenant_id, object_identifier) pair
  # - The found identity's status_id is not ACTIVE
  #
  # Never creates records. Sign-in fails loudly on miss -- no JIT provisioning.
  # The tenant is restricted upstream: the strategy verifies the ID token
  # against the single configured tenant, so a token from any other tenant
  # cannot reach this resolver.
  class OrgEntraResolver
    Result = Data.define(:identity, :operator)

    def initialize(tenant_context:)
      @tenant_context = tenant_context
    end

    def call
      identity = OperatorEntraIdentity.find_by(
        entra_tenant_id: tenant_context.tenant_id,
        entra_object_id: tenant_context.object_identifier,
      )

      raise IdentityNotFoundError,
            "no identity provisioned for (#{tenant_context.tenant_id}, " \
            "#{tenant_context.object_identifier})" if identity.nil?
      raise IdentityNotFoundError, "identity is not active" unless identity.status_id == OperatorEntraIdentityState::ACTIVE

      Result.new(identity: identity, operator: operator_for(identity))
    end

    private

    attr_reader :tenant_context

    def operator_for(identity)
      Operator.find_by(id: identity.operator_id)
    end
  end
end
