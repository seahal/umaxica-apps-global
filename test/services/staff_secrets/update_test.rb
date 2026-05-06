# typed: false
# frozen_string_literal: true

require "test_helper"

class StaffSecrets::UpdateTest < ActiveSupport::TestCase
  fixtures :staff_statuses, :staff_email_statuses, :staff_secret_statuses, :staffs

  setup do
    @staff = staffs(:one)
    StaffEmail.create!(
      staff: @staff,
      address: "secret-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )
    @secret = StaffSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: StaffSecret.generate_raw_secret,
      staff_secret_status_id: StaffSecretStatus::ACTIVE,
    )
  end

  test "updates secret name" do
    params = { name: "Updated Name" }

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_equal "Updated Name", result.secret.name
  end

  test "updates secret status to revoked" do
    params = { enabled: false }

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_predicate result.secret, :revoked?
  end

  test "updates secret status to active" do
    @secret.update!(staff_secret_status_id: StaffSecretStatus::REVOKED)
    params = { enabled: true }

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_predicate result.secret, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  updated-name-with-spaces  " }

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_equal "updated-name-with-spaces", result.secret.name
  end

  test "does not update name when not present in params" do
    original_name = @secret.name
    params = { enabled: false }

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_equal original_name, result.secret.name
  end

  test "does not update status when not present in params" do
    params = { name: "New Name" }
    original_status = @secret.staff_secret_status_id

    result = StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)

    assert_equal original_status, result.secret.staff_secret_status_id
  end

  test "creates StaffChronicle audit" do
    params = { name: "Audit Test" }

    assert_difference("StaffChronicle.count", 1) do
      StaffSecrets::Update.call(actor: @staff, secret: @secret, params: params)
    end

    activity = StaffChronicle.last

    assert_equal StaffChronicleEvent::STAFF_SECRET_UPDATED, activity.event_id
  end
end
