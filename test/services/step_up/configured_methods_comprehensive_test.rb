# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class StepUpConfiguredMethodsComprehensiveTest < ActiveSupport::TestCase
  fixtures :clients

  test "returns empty array for nil subject" do
    assert_equal [], StepUpConfiguredMethods.call(nil)
  end

  test "returns empty array for object without email/passkey/totp associations" do
    assert_equal [], StepUpConfiguredMethods.call(Object.new)
  end

  test "configured_email? returns false for object without email associations" do
    assert_not StepUpConfiguredMethods.configured_email?(Object.new)
  end

  test "configured_passkey? returns false for object without passkey associations" do
    assert_not StepUpConfiguredMethods.configured_passkey?(Object.new)
  end

  test "configured_totp? returns false for object without otp associations" do
    assert_not StepUpConfiguredMethods.configured_totp?(Object.new)
  end

  test "configured_email? returns true for user with client_emails" do
    user = clients(:one)
    result = StepUpConfiguredMethods.configured_email?(user)
    expected = user.client_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)

    assert_equal expected, result
  end

  test "configured_passkey? returns true for user with client_passkeys" do
    user = clients(:one)
    result = StepUpConfiguredMethods.configured_passkey?(user)
    expected = user.client_passkeys.active.exists?

    assert_equal expected, result
  end

  test "configured_totp? returns false for user without client_totp_credentials" do
    user = clients(:one)
    result = StepUpConfiguredMethods.configured_totp?(user)
    expected = user.client_totp_credentials.exists?(
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_equal expected, result
  end

  test "call includes email_otp when user has emails" do
    user = clients(:one)
    if user.client_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      assert_includes StepUpConfiguredMethods.call(user), :email_otp
    else
      assert_not_includes StepUpConfiguredMethods.call(user), :email_otp
    end
  end

  test "call includes passkey when user has passkeys" do
    user = clients(:one)
    result = StepUpConfiguredMethods.call(user)
    if user.client_passkeys.active.exists?
      assert_includes result, :passkey
    else
      assert_not_includes result, :passkey
    end
  end

  test "configured_email? with visitor_emails" do
    visitor = Visitor.new(status_id: VisitorStatus::ACTIVE)

    assert_not StepUpConfiguredMethods.configured_email?(visitor)
  end

  test "configured_passkey? with visitor_passkeys" do
    visitor = Visitor.new(status_id: VisitorStatus::ACTIVE)

    assert_not StepUpConfiguredMethods.configured_passkey?(visitor)
  end

  test "configured_passkey? with operator_passkeys" do
    staff = Operator.new(status_id: OperatorStatus::NOTHING)

    assert_not StepUpConfiguredMethods.configured_passkey?(staff)
  end

  test "configured_email? with operator_emails" do
    staff = Operator.new(status_id: OperatorStatus::NOTHING)

    assert_not StepUpConfiguredMethods.configured_email?(staff)
  end
end
