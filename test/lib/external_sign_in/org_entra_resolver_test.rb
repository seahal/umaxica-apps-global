# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalSignIn::OrgEntraResolverTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @active_connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "resolver-test-client-id",
      entra_client_secret: "resolver-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )

    @active_identity = OperatorEntraIdentity.create!(
      operator_id: 9001,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
  end

  # --- success path ---

  test "returns the OperatorEntraIdentity when identity and connection are both ACTIVE" do
    result = resolve(tenant_id: TENANT_ID, object_id: OBJECT_ID)

    assert_equal @active_identity.id, result.id
    assert_equal 9001, result.operator_id
  end

  test "returns an identity with its connection preloaded" do
    result = resolve(tenant_id: TENANT_ID, object_id: OBJECT_ID)

    assert_predicate result.association(:connection), :loaded?
  end

  # --- identity not found ---

  test "raises IdentityNotFoundError when no identity matches (tid, oid)" do
    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: "00000000-0000-0000-0000-000000000000")
    end
  end

  test "raises IdentityNotFoundError when identity is NOTHING (not yet activated)" do
    inactive_identity = OperatorEntraIdentity.create!(
      operator_id: 9002,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: inactive_identity.entra_object_id)
    end
  end

  test "raises IdentityNotFoundError when identity is SUSPENDED" do
    suspended = OperatorEntraIdentity.create!(
      operator_id: 9003,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "cccccccc-dddd-eeee-ffff-000000000000",
      status_id: OperatorEntraIdentityState::SUSPENDED,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: suspended.entra_object_id)
    end
  end

  test "raises IdentityNotFoundError when identity is REVOKED" do
    revoked = OperatorEntraIdentity.create!(
      operator_id: 9004,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "dddddddd-eeee-ffff-0000-111111111111",
      status_id: OperatorEntraIdentityState::REVOKED,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: revoked.entra_object_id)
    end
  end

  # --- connection not active ---

  test "raises IdentityNotFoundError when connection is NOTHING (not yet activated)" do
    inactive_connection = OrganizationEntraConnection.create!(
      organization_id: 2,
      entra_tenant_id: "22222222-3333-4444-5555-666666666666",
      entra_client_id: "inactive-conn-client",
      entra_client_secret: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    other_oid = "eeeeeeee-ffff-0000-1111-222222222222"
    OperatorEntraIdentity.create!(
      operator_id: 9005,
      connection_id: inactive_connection.id,
      entra_tenant_id: "22222222-3333-4444-5555-666666666666",
      entra_object_id: other_oid,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: "22222222-3333-4444-5555-666666666666", object_id: other_oid)
    end
  end

  test "raises IdentityNotFoundError when connection is SUSPENDED" do
    suspended_connection = OrganizationEntraConnection.create!(
      organization_id: 3,
      entra_tenant_id: "33333333-4444-5555-6666-777777777777",
      entra_client_id: "suspended-conn-client",
      entra_client_secret: "secret",
      status_id: OrganizationEntraConnectionState::SUSPENDED,
    )

    other_oid = "ffffffff-0000-1111-2222-333333333333"
    OperatorEntraIdentity.create!(
      operator_id: 9006,
      connection_id: suspended_connection.id,
      entra_tenant_id: "33333333-4444-5555-6666-777777777777",
      entra_object_id: other_oid,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: "33333333-4444-5555-6666-777777777777", object_id: other_oid)
    end
  end

  # --- no provisioning side-effects ---

  test "does not create any record when no identity is found" do
    count_before = OperatorEntraIdentity.count

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: "00000000-0000-0000-0000-000000000000")
    end

    assert_equal count_before, OperatorEntraIdentity.count
  end

  private

  def auth_result(tenant_id:, object_id:)
    ExternalSignIn::NormalizedAuthResult.new(
      tenant_id: tenant_id,
      entra_object_id: object_id,
      evidence_issuer: "https://login.microsoftonline.com/#{tenant_id}/v2.0",
      evidence_subject: "pairwise-sub",
    )
  end

  def resolve(tenant_id:, object_id:)
    ExternalSignIn::OrgEntraResolver.new(
      auth_result: auth_result(tenant_id: tenant_id, object_id: object_id),
    ).call
  end
end
