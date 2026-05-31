# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOrgVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Preference::Global
    include Common::Otp
    include Authentication::Operator
    include Verification::Operator
    include Sign::Webauthn
    include Sign::VerificationTiming
    include Sign::VerificationCommonBase
    include Sign::VerificationAuditAndCookie
    include Sign::VerificationStepUpSessionStore
    include Sign::VerificationStepUpLifecycle
    include Sign::VerificationPasskeyChecks
    include Sign::OrgVerificationBase
  end

  test "included do includes Preference::Global module" do
    assert_includes Harness.included_modules, Preference::Global
  end

  test "included do includes Common::Otp module" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "included do includes Authentication::Operator module" do
    assert_includes Harness.included_modules, Authentication::Operator
  end

  test "included do includes Verification::Operator module" do
    assert_includes Harness.included_modules, Verification::Operator
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

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, Sign::OrgVerificationBase::STEP_UP_TTL
  end

  test "STEP_UP_SESSION_KEY constant is defined" do
    assert_equal :step_up, Sign::OrgVerificationBase::STEP_UP_SESSION_KEY
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, Sign::OrgVerificationBase::ALLOWED_SCOPES
    assert Sign::OrgVerificationBase::ALLOWED_SCOPES.key?("configuration_passkey")
    assert Sign::OrgVerificationBase::ALLOWED_SCOPES.key?("configuration_mfa")
  end
end
