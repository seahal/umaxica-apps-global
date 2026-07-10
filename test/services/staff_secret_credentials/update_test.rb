# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsUpdateTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operator_secret_credential_statuses, :operators

  setup do
    @staff = operators(:one)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    @secret_credential = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret",
      password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  test "updates secret_credential name" do
    params = { name: "Updated Name" }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_equal "Updated Name", result.secret_credential.name
  end

  test "updates secret_credential status to revoked" do
    params = { enabled: false }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_predicate result.secret_credential, :revoked?
  end

  test "updates secret_credential status to active" do
    @secret_credential.update!(staff_secret_status_id: OperatorSecretCredentialStatus::REVOKED)
    params = { enabled: true }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_predicate result.secret_credential, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  updated-name-with-spaces  " }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_equal "updated-name-with-spaces", result.secret_credential.name
  end

  test "does not update name when not present in params" do
    original_name = @secret_credential.name
    params = { enabled: false }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_equal original_name, result.secret_credential.name
  end

  test "does not update status when not present in params" do
    params = { name: "New Name" }
    original_status = @secret_credential.staff_secret_status_id

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential,
      params: params,
    )

    assert_equal original_status, result.secret_credential.staff_secret_status_id
  end

  test "creates OperatorChronicle audit" do
    params = { name: "Audit Test" }

    assert_difference("OperatorChronicle.count", 1) do
      OperatorSecretCredentialsUpdate.call(actor: @staff, secret_credential: @secret_credential, params: params)
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_UPDATED, activity.event_id
  end
end
