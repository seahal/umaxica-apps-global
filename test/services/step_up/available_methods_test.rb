# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class StepUpAvailableMethodsTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  setup do
    @user = Client.create!(status_id: ClientStatus::NOTHING)
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
  end

  test "includes email_otp for verified user email status" do
    @user.client_emails.create!(
      address: "verified-stepup@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_includes StepUpAvailableMethods.call(@user), :email_otp
  end

  test "matches configured methods without cooldown or lockout" do
    @user.client_emails.create!(
      address: "available-baseline@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal StepUpConfiguredMethods.call(@user), StepUpAvailableMethods.call(@user)
  end

  test "cooldown stamp does not hide methods while cache-backed cooldowns are disabled" do
    @user.client_emails.create!(
      address: "available-cooldown@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    passkey = @user.client_passkeys.new(
      webauthn_id: "available_cooldown_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "cooldown passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    StepUpCooldownStamp.call(@user, :email_otp)

    result = StepUpAvailableMethods.call(@user)

    assert_includes result, :email_otp
    assert_includes result, :passkey
  end

  test "email otp cooldown window is sixty seconds" do
    assert_equal 60.seconds, StepUpCooldowns::WINDOWS.fetch(:email_otp)
    assert_equal StepUpCooldowns::WINDOWS.fetch(:email_otp),
                 SignAppVerificationBase::EMAIL_OTP_RESEND_COOLDOWN
  end

  test "ticket lockout returns no methods" do
    @user.client_emails.create!(
      address: "available-lockout@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    ticket = Struct.new(:attempt_count).new(5)

    assert_equal [], StepUpAvailableMethods.call(@user, ticket: ticket)
  end

  test "ticket attempt count four still returns configured methods" do
    @user.client_emails.create!(
      address: "available-attempt-four@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    ticket = Struct.new(:attempt_count).new(4)

    assert_includes StepUpAvailableMethods.call(@user, ticket: ticket), :email_otp
  end

  test "does not include email_otp for unverified user email status" do
    @user.client_emails.create!(
      address: "unverified-stepup@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_not_includes StepUpAvailableMethods.call(@user), :email_otp
  end

  test "includes passkey for active passkey status" do
    passkey =
      @user.client_passkeys.new(
        webauthn_id: "stepup_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "stepup passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )
    passkey.save!(validate: false)

    assert_includes StepUpAvailableMethods.call(@user), :passkey
  end

  test "does not include passkey for inactive passkey status" do
    user = Client.create!
    passkey =
      user.client_passkeys.new(
        webauthn_id: "stepup_inactive_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "inactive passkey",
        status_id: ClientPasskeyStatus::DISABLED,
      )
    passkey.save!(validate: false)

    assert_not_includes StepUpAvailableMethods.call(user), :passkey
  end

  test "includes totp for active totp status" do
    @user.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_includes StepUpAvailableMethods.call(@user), :totp
  end

  test "does not include totp for inactive totp status" do
    user = Client.create!
    user.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_not_includes StepUpAvailableMethods.call(user), :totp
  end

  test "does not include email_otp for active staff email status" do
    @staff.operator_emails.create!(
      address: "staff-active-stepup@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::ACTIVE,
      otp_counter: "0",
      otp_private_key: "private_key",
    )

    assert_not_includes StepUpAvailableMethods.call(@staff), :email_otp
  end

  test "available methods ignore cooldown stamps for visitor actors while cache-backed cooldowns are disabled" do
    ensure_visitor_reference_records!
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    @visitor.visitor_emails.create!(
      address: "available-visitor@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_includes StepUpAvailableMethods.call(@visitor), :email_otp

    StepUpCooldownStamp.call(@visitor, :email_otp)

    assert_includes StepUpAvailableMethods.call(@visitor), :email_otp
  end

  test "available methods apply lockout for staff actors" do
    passkey = @staff.operator_passkeys.new(
      webauthn_id: "staff_lockout_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "staff lockout passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)
    ticket = Struct.new(:attempt_count).new(5)

    assert_equal [], StepUpAvailableMethods.call(@staff, ticket: ticket)
  end

  test "does not include email_otp for inactive staff email status" do
    @staff.operator_emails.create!(
      address: "staff-inactive-stepup@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::INACTIVE,
      otp_counter: "0",
      otp_private_key: "private_key",
    )

    assert_not_includes StepUpAvailableMethods.call(@staff), :email_otp
  end
end
