# typed: false
# frozen_string_literal: true

# Moves a provisioned OperatorEntraIdentity between the states that decide
# whether it may complete a sign-in. Administrator tooling, reachable only
# through `rake entra_identity:activate` / `:suspend` / `:revoke`.
#
# Activation is separate from provisioning on purpose: the data layer is
# deny-by-default (adr/org-entra-id-sign-in-boundary.md), so creating the mapping
# and permitting sign-in with it are two decisions, each recorded on its own.
#
# ExternalSignIn::OrgEntraResolver admits only ACTIVE identities, so suspending or
# revoking here stops that operator's Entra sign-in on the next attempt without
# deleting the mapping or its audit evidence.
class OperatorEntraIdentityActivation < ApplicationService
  Result = Data.define(:identity, :previous_state, :state)

  class Error < StandardError; end

  class IdentityNotFound < Error; end

  class UnsupportedState < Error; end

  STATES = {
    "active" => OperatorEntraIdentityState::ACTIVE,
    "suspended" => OperatorEntraIdentityState::SUSPENDED,
    "revoked" => OperatorEntraIdentityState::REVOKED,
  }.freeze

  def initialize(operator_public_id:, state:)
    super()
    @operator_public_id = operator_public_id.to_s
    @state = state.to_s.strip.downcase
  end

  def call
    status_id =
      STATES.fetch(state) do
        raise UnsupportedState, "state must be one of #{STATES.keys.join(", ")}"
      end

    identity = find_identity!
    previous = state_name_for(identity.status_id)
    identity.update!(status_id: status_id)

    Result.new(identity: identity, previous_state: previous, state: state)
  end

  private

  attr_reader :operator_public_id, :state

  def find_identity!
    normalized = Operator.normalize_public_id(operator_public_id)
    operator = Operator.find_by(public_id: normalized)
    raise IdentityNotFound, "no operator with public_id #{normalized.inspect}" if operator.nil?

    identity = OperatorEntraIdentity.find_by(operator_id: operator.id)
    raise IdentityNotFound, "operator #{normalized} has no Entra identity to change" if identity.nil?

    identity
  end

  def state_name_for(status_id)
    STATES.key(status_id) || "inactive"
  end
end
