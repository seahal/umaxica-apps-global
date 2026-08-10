# typed: false
# frozen_string_literal: true

class OrgEntraIdentityResolver
  def self.call(authentication_result:, connection:)
    new(authentication_result: authentication_result, connection: connection).call
  end

  def initialize(authentication_result:, connection:)
    @authentication_result = authentication_result
    @connection = connection
  end

  def call
    raise ArgumentError, "authentication_result must be verified" unless authentication_result.verified?

    identity = OperatorEntraIdentity
      .includes(:connection)
      .find_by(
        connection_id: connection.id,
        entra_tenant_id: authentication_result.tenant_id,
        entra_object_id: authentication_result.entra_object_id,
      )
    return rejected("identity_not_found") if identity.nil?
    return rejected("identity_inactive") unless identity.status_id == OperatorEntraIdentityState::ACTIVE
    return rejected("connection_inactive") unless identity.connection.status_id == OrganizationEntraConnectionState::ACTIVE

    operator = Operator.find_by(id: identity.operator_id)
    return rejected("operator_not_found", identity: identity) if operator.nil?

    OrgEntraIdentityResolution.resolved(identity: identity, operator: operator)
  end

  private

  attr_reader :authentication_result, :connection

  def rejected(error, identity: nil)
    OrgEntraIdentityResolution.rejected(error: error, identity: identity)
  end
end
