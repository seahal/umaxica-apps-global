# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorSecrets::CreateTest < ActiveSupport::TestCase
  fixtures :staff_statuses, :staff_email_statuses, :staffs

  setup do
    @staff = staffs(:one)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end

  test "creates secret with auto-generated raw secret" do
    params = { name: "api-key-1", enabled: true }

    result = OperatorSecrets::Create.call(actor: @staff, staff: @staff, params: params)

    assert_predicate result.secret, :persisted?
    assert_predicate result.raw_secret, :present?
    assert_equal "api-key-1", result.secret.name
    assert_predicate result.secret, :active?
  end

  test "creates secret with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = OperatorSecrets::Create.call(actor: @staff, staff: @staff, params: params)

    assert_predicate result.secret, :revoked?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = OperatorSecrets::Create.call(actor: @staff, staff: @staff, params: params)

    assert_equal "test-name-with-spaces", result.secret.name
  end
end
