# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUp::ConfiguredMethodsTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @user = clients(:one)
  end

  test "does not include email_otp for unverified email" do
    @user.client_emails.create!(
      address: "configured-unverified@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_not_includes StepUp::ConfiguredMethods.call(@user), :email_otp
  end

  test "includes email_otp for verified email" do
    @user.client_emails.create!(
      address: "configured-verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_includes StepUp::ConfiguredMethods.call(@user), :email_otp
  end

  test "returns credential-backed visitor methods" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    visitor.visitor_emails.create!(
      address: "configured-visitor@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    passkey = visitor.visitor_passkeys.new(
      webauthn_id: "configured_visitor_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "visitor passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    result = StepUp::ConfiguredMethods.call(visitor)

    assert_includes result, :passkey
    assert_includes result, :email_otp
    assert_not_includes result, :totp
  end

  test "returns credential-backed staff methods" do
    staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    staff.operator_emails.create!(
      address: "configured-staff@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::ACTIVE,
      otp_counter: "0",
      otp_private_key: "private_key",
    )
    passkey = staff.operator_passkeys.new(
      webauthn_id: "configured_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "staff passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    result = StepUp::ConfiguredMethods.call(staff)

    assert_not_includes result, :email_otp
    assert_includes result, :passkey
    assert_not_includes result, :totp
  end

  test "does not include inactive totp" do
    user = Client.create!
    user.client_one_time_passwords.create!(
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::INACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_not_includes StepUp::ConfiguredMethods.call(user), :totp
  end

  test "does not include inactive passkey" do
    user = Client.create!
    passkey =
      user.client_passkeys.new(
        webauthn_id: "configured_inactive_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "inactive passkey",
        status_id: ClientPasskeyStatus::DISABLED,
      )
    passkey.save!(validate: false)

    assert_not_includes StepUp::ConfiguredMethods.call(user), :passkey
  end
end
