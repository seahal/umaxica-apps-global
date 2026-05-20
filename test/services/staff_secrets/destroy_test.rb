# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorSecrets::DestroyTest < ActiveSupport::TestCase
  fixtures :operator_identity_statuses, :operator_email_statuses, :operator_secret_statuses, :operators

  setup do
    @staff = operators(:one)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    @secret = OperatorSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: OperatorSecret.generate_raw_secret,
      staff_secret_status_id: OperatorSecretStatus::ACTIVE,
    )
  end

  test "destroys staff secret" do
    assert_difference("OperatorSecret.count", -1) do
      OperatorSecrets::Destroy.call(actor: @staff, secret: @secret)
    end
  end

  test "creates OperatorChronicle audit" do
    assert_difference("OperatorChronicle.count", 1) do
      OperatorSecrets::Destroy.call(actor: @staff, secret: @secret)
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_REMOVED, activity.event_id
    assert_equal @staff, activity.actor
    assert_equal @secret.id, activity.subject_id
  end
end
