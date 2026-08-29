# typed: false
# frozen_string_literal: true

# Creates the OperatorEntraIdentity that lets one operator sign in with Microsoft
# Entra ID. Administrator tooling, reachable only through
# `rake entra_identity:provision`; nothing in the request path calls it.
#
# The org Entra ceremony performs no JIT provisioning, so this is the only way an
# operator can ever complete an Entra sign-in
# (adr/org-entra-id-sign-in-boundary.md).
#
# Two properties are deliberate and should not be "improved" away:
#
# - The tenant is never an argument. It is read from the pinned single-tenant
#   configuration, so an administrator cannot provision an identity in a tenant
#   this deployment does not federate.
# - The record is created inactive. Activation is a separate, explicit act
#   (OperatorEntraIdentityActivation), which keeps the data layer deny-by-default
#   and makes "provisioned" and "allowed to sign in" two auditable decisions.
#
# The operator is addressed by public_id: an administrator reads it from the
# operator record, never from an email address or Entra profile field.
class OperatorEntraIdentityProvisioner < ApplicationService
  Result = Data.define(:identity, :tenant_id, :operator_public_id)

  class Error < StandardError; end

  class OperatorNotFound < Error; end

  class AlreadyProvisioned < Error; end

  class InvalidObjectId < Error; end

  OBJECT_ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  private_constant :OBJECT_ID_FORMAT

  def initialize(operator_public_id:, entra_object_id:)
    super()
    @operator_public_id = operator_public_id.to_s
    @entra_object_id = entra_object_id.to_s.strip.downcase
  end

  def call
    raise InvalidObjectId, "entra_object_id must be a UUID (the Entra user's Object ID)" unless valid_object_id?

    operator = find_operator!
    guard_unprovisioned!(operator)

    identity = OperatorEntraIdentity.create!(
      operator_id: operator.id,
      entra_tenant_id: tenant_id,
      entra_object_id: entra_object_id,
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    Result.new(identity: identity, tenant_id: tenant_id, operator_public_id: operator.public_id)
  end

  private

  attr_reader :operator_public_id, :entra_object_id

  def tenant_id
    @tenant_id ||= ExternalAuthentication::ProviderRegistry.tenant_id("entra")
  end

  def valid_object_id?
    entra_object_id.match?(OBJECT_ID_FORMAT)
  end

  def find_operator!
    normalized = Operator.normalize_public_id(operator_public_id)
    operator = Operator.find_by(public_id: normalized)
    raise OperatorNotFound, "no operator with public_id #{normalized.inspect}" if operator.nil?

    operator
  end

  # Both directions are refused rather than updated in place. Repointing an
  # existing mapping is an identity change, not a provisioning step, and doing it
  # silently would let a typo move an Entra account onto another operator.
  def guard_unprovisioned!(operator)
    existing = OperatorEntraIdentity.find_by(operator_id: operator.id)
    if existing
      raise AlreadyProvisioned,
            "operator #{operator.public_id} already has an Entra identity (#{existing.public_id})"
    end

    claimed = OperatorEntraIdentity.find_by(entra_tenant_id: tenant_id, entra_object_id: entra_object_id)
    return if claimed.nil?

    raise AlreadyProvisioned, claim_message(claimed)
  end

  # A withdrawn mapping still occupies its (tid, oid) until retention purge
  # removes it, so a returning person cannot be provisioned onto the same Entra
  # object yet. Saying so is the difference between an administrator waiting for
  # the purge and an administrator hunting for an operator that no longer exists.
  def claim_message(claimed)
    withdrawn = [OperatorEntraIdentityState::SUSPENDED, OperatorEntraIdentityState::REVOKED]
    if withdrawn.include?(claimed.status_id)
      "that Entra object is still mapped to a withdrawn operator (identity #{claimed.public_id}); " \
        "the mapping is kept for audit until retention purge removes it"
    else
      "that Entra object is already mapped to another operator (identity #{claimed.public_id})"
    end
  end
end
