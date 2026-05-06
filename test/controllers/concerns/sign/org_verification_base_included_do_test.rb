# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOrgVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::OrgVerificationBase
  end

  test "included do includes Preference::Global module" do
    assert_includes Harness.included_modules, Preference::Global
  end

  test "included do includes Common::Otp module" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "included do includes Authentication::Staff module" do
    assert_includes Harness.included_modules, Authentication::Staff
  end

  test "included do includes Verification::Staff module" do
    assert_includes Harness.included_modules, Verification::Staff
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

  test "REAUTH_TTL constant is defined" do
    assert_equal 15.minutes, Sign::OrgVerificationBase::REAUTH_TTL
  end

  test "REAUTH_SESSION_KEY constant is defined" do
    assert_equal :reauth, Sign::OrgVerificationBase::REAUTH_SESSION_KEY
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, Sign::OrgVerificationBase::ALLOWED_SCOPES
    assert Sign::OrgVerificationBase::ALLOWED_SCOPES.key?("configuration_passkey")
    assert Sign::OrgVerificationBase::ALLOWED_SCOPES.key?("configuration_mfa")
  end
end
