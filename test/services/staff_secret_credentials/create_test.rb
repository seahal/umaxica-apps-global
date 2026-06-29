# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class StaffSecretCredentialsCreateTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operators

  setup do
    @staff = operators(:one)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end

  test "creates secret_credential with auto-generated raw secret_credential" do
    params = { name: "api-key-1", enabled: true }

    result = OperatorSecretCredentialsCreate.call(actor: @staff, staff: @staff, params: params)

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_predicate result.secret_credential, :active?
  end

  test "creates secret_credential with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = OperatorSecretCredentialsCreate.call(actor: @staff, staff: @staff, params: params)

    assert_predicate result.secret_credential, :revoked?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = OperatorSecretCredentialsCreate.call(actor: @staff, staff: @staff, params: params)

    assert_equal "test-name-with-spaces", result.secret_credential.name
  end
end
