# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgEntraIdentityResolverTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "resolver-test-client-id",
      entra_client_secret: "resolver-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @identity = OperatorEntraIdentity.create!(
      operator_id: @operator.id,
      connection_id: @connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
    @authentication = EntraAuthenticationResult.verified(
      tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      evidence_issuer: "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
      evidence_subject: "pairwise-subject",
    )
  end

  test "resolves an active identity and its operator without creating records" do
    count_before = OperatorEntraIdentity.count

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: @authentication,
      connection: @connection,
    )

    assert_predicate resolution, :resolved?
    assert_equal @identity, resolution.identity
    assert_equal @operator, resolution.operator
    assert_predicate resolution.identity.association(:connection), :loaded?
    assert_equal count_before, OperatorEntraIdentity.count
  end

  test "rejects a missing identity without provisioning one" do
    missing_authentication = EntraAuthenticationResult.verified(
      tenant_id: TENANT_ID,
      entra_object_id: "00000000-0000-0000-0000-000000000000",
      evidence_issuer: "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
      evidence_subject: "missing-subject",
    )
    count_before = OperatorEntraIdentity.count

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: missing_authentication,
      connection: @connection,
    )

    assert_predicate resolution, :rejected?
    assert_equal "identity_not_found", resolution.error
    assert_equal count_before, OperatorEntraIdentity.count
  end

  test "rejects an active identity whose logical operator reference is stale" do
    @identity.update!(operator_id: 9_999_999)

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: @authentication,
      connection: @connection,
    )

    assert_predicate resolution, :rejected?
    assert_equal "operator_not_found", resolution.error
    assert_equal @identity, resolution.identity
    assert_nil resolution.operator
  end

  test "rejects an inactive identity" do
    @identity.update!(status_id: OperatorEntraIdentityState::SUSPENDED)

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: @authentication,
      connection: @connection,
    )

    assert_predicate resolution, :rejected?
    assert_equal "identity_inactive", resolution.error
  end

  test "rejects an inactive connection" do
    @connection.update!(status_id: OrganizationEntraConnectionState::SUSPENDED)

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: @authentication,
      connection: @connection,
    )

    assert_predicate resolution, :rejected?
    assert_equal "connection_inactive", resolution.error
  end

  test "does not resolve an identity through a different connection" do
    other_connection = OrganizationEntraConnection.create!(
      organization_id: 2,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "resolver-other-client-id",
      entra_client_secret: "resolver-other-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )

    resolution = OrgEntraIdentityResolver.call(
      authentication_result: @authentication,
      connection: other_connection,
    )

    assert_predicate resolution, :rejected?
    assert_equal "identity_not_found", resolution.error
  end

  test "raises for an unverified authentication value" do
    rejected_authentication = EntraAuthenticationResult.rejected(error: "nonce_mismatch")

    assert_raises(ArgumentError) do
      OrgEntraIdentityResolver.call(
        authentication_result: rejected_authentication,
        connection: @connection,
      )
    end
  end
end
