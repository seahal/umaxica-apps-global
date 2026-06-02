# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Preference::Global
    include Common::Otp
    include Verification::Client
    include Sign::Webauthn
    include Sign::VerificationTiming
    include Sign::VerificationCommonBase
    include Sign::VerificationAuditAndCookie
    include Sign::VerificationStepUpSessionStore
    include Sign::VerificationStepUpLifecycle
    include Sign::VerificationPasskeyChecks
    include Sign::VerificationTotpChecks
    include Sign::AppVerificationBase
  end

  test "included do includes Preference::Global module" do
    assert_includes Harness.included_modules, Preference::Global
  end

  test "included do includes Common::Otp module" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "included do includes Verification::Client module" do
    assert_includes Harness.included_modules, Verification::Client
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

  test "included do includes Sign::VerificationStepUpSessionStore module" do
    assert_includes Harness.included_modules, Sign::VerificationStepUpSessionStore
  end

  test "included do includes Sign::VerificationStepUpLifecycle module" do
    assert_includes Harness.included_modules, Sign::VerificationStepUpLifecycle
  end

  test "included do includes Sign::VerificationPasskeyChecks module" do
    assert_includes Harness.included_modules, Sign::VerificationPasskeyChecks
  end

  test "included do includes Sign::VerificationTotpChecks module" do
    assert_includes Harness.included_modules, Sign::VerificationTotpChecks
  end

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, Sign::AppVerificationBase::STEP_UP_TTL
  end

  test "STEP_UP_SESSION_KEY constant is defined" do
    assert_equal :step_up, Sign::AppVerificationBase::STEP_UP_SESSION_KEY
  end

  test "EMAIL_OTP_SESSION_KEY constant is defined" do
    assert_equal :step_up_email_otp, Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, Sign::AppVerificationBase::ALLOWED_SCOPES
    assert Sign::AppVerificationBase::ALLOWED_SCOPES.key?("settings_email")
    assert Sign::AppVerificationBase::ALLOWED_SCOPES.key?("settings_telephone")
  end
end
