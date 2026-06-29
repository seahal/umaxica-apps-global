# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOrgVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceGlobal
    include CommonOtp
    include AuthenticationOperator
    include VerificationOperator
    include SignWebauthn
    include SignVerificationTiming
    include SignVerificationCommonBase
    include SignVerificationAuditAndCookie
    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignVerificationPasskeyChecks
    include SignOrgVerificationBase
  end

  test "included do includes PreferenceGlobal module" do
    assert_includes Harness.included_modules, PreferenceGlobal
  end

  test "included do includes CommonOtp module" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "included do includes AuthenticationOperator module" do
    assert_includes Harness.included_modules, AuthenticationOperator
  end

  test "included do includes VerificationOperator module" do
    assert_includes Harness.included_modules, VerificationOperator
  end

  test "included do includes SignWebauthn module" do
    assert_includes Harness.included_modules, SignWebauthn
  end

  test "included do includes SignVerificationTiming module" do
    assert_includes Harness.included_modules, SignVerificationTiming
  end

  test "included do includes SignVerificationCommonBase module" do
    assert_includes Harness.included_modules, SignVerificationCommonBase
  end

  test "included do includes SignVerificationAuditAndCookie module" do
    assert_includes Harness.included_modules, SignVerificationAuditAndCookie
  end

  test "included do includes SignVerificationStepUpSessionStore module" do
    assert_includes Harness.included_modules, SignVerificationStepUpSessionStore
  end

  test "included do includes SignVerificationStepUpLifecycle module" do
    assert_includes Harness.included_modules, SignVerificationStepUpLifecycle
  end

  test "included do includes SignVerificationPasskeyChecks module" do
    assert_includes Harness.included_modules, SignVerificationPasskeyChecks
  end

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, SignOrgVerificationBase::STEP_UP_TTL
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, SignOrgVerificationBase::ALLOWED_SCOPES
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_passkey")
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_mfa")
  end
end
