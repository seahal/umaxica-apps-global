# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::AppVerificationBase
  end

  test "included do includes Preference::Global module" do
    assert_includes Harness.included_modules, Preference::Global
  end

  test "included do includes Common::Otp module" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "included do includes Verification::User module" do
    assert_includes Harness.included_modules, Verification::User
  end

  test "included do includes Sign::Webauthn module" do
    assert_includes Harness.included_modules, Sign::Webauthn
  end

  test "included do includes Sign::VerificationTiming module" do
    assert_includes Harness.included_modules, Sign::VerificationTiming
  end

  test "included do includes Sign::VerificationCommonBase module" do
    assert_includes Harness.included_modules, Sign::VerificationCommonBase
  end

  test "included do includes Sign::VerificationAuditAndCookie module" do
    assert_includes Harness.included_modules, Sign::VerificationAuditAndCookie
  end

  test "included do includes Sign::VerificationReauthSessionStore module" do
    assert_includes Harness.included_modules, Sign::VerificationReauthSessionStore
  end

  test "included do includes Sign::VerificationReauthLifecycle module" do
    assert_includes Harness.included_modules, Sign::VerificationReauthLifecycle
  end

  test "included do includes Sign::VerificationPasskeyChecks module" do
    assert_includes Harness.included_modules, Sign::VerificationPasskeyChecks
  end

  test "included do includes Sign::VerificationTotpChecks module" do
    assert_includes Harness.included_modules, Sign::VerificationTotpChecks
  end

  test "REAUTH_TTL constant is defined" do
    assert_equal 15.minutes, Sign::AppVerificationBase::REAUTH_TTL
  end

  test "REAUTH_SESSION_KEY constant is defined" do
    assert_equal :reauth, Sign::AppVerificationBase::REAUTH_SESSION_KEY
  end

  test "EMAIL_OTP_SESSION_KEY constant is defined" do
    assert_equal :reauth_email_otp, Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, Sign::AppVerificationBase::ALLOWED_SCOPES
    assert Sign::AppVerificationBase::ALLOWED_SCOPES.key?("configuration_email")
    assert Sign::AppVerificationBase::ALLOWED_SCOPES.key?("configuration_telephone")
  end
end
