# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEmailOtpVerificationSupportTest < ActiveSupport::TestCase
  class Harness
    include SignEmailOtpVerificationSupport

    attr_accessor :params, :session, :current_step_up_session, :verification_errors

    def initialize
      @params = ActionController::Parameters.new({})
      @session = {}
    end

    def request
      nil
    end
  end

  test "verification recovery params keep present scope and pt" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(verification: { scope: "settings_email", pt: "abc" }, ri: "jp")

    assert_equal({ ri: "jp", scope: "settings_email", pt: "abc" }, harness.send(:verification_recovery_redirect_params))
  end

  test "verify_email_otp rejects invalid missing and mismatched codes" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(verification: { code: "12" })

    assert_not harness.send(:verify_email_otp!)
    assert_equal [I18n.t("sign.app.verification.errors.invalid_code")], harness.verification_errors

    harness.params = ActionController::Parameters.new(verification: { code: "123456" })

    assert_not harness.send(:verify_email_otp!)
    assert_equal [I18n.t("sign.app.verification.errors.resend_required")], harness.verification_errors

    session = Object.new
    session.define_singleton_method(:id) { 11 }
    session.define_singleton_method(:discarded_at) { 1.minute.ago }
    harness.current_step_up_session = session
    harness.session[:sign_step_up_email_otp] = {
      "step_up_session_id" => 11,
      "expires_at" => 1.hour.from_now.to_i,
      "otp_digest" => "deadbeef",
    }
    harness.params = ActionController::Parameters.new(verification: { code: "123456" })

    assert_not harness.send(:verify_email_otp!)
    assert_equal [I18n.t("sign.app.verification.errors.code_expired")], harness.verification_errors

    session.define_singleton_method(:discarded_at) { 1.hour.from_now }
    harness.current_step_up_session = session

    assert_not harness.send(:verify_email_otp!)
    assert_equal [I18n.t("sign.app.verification.errors.incorrect_code")], harness.verification_errors
  end

  test "restore step up session from params returns false without both values" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(verification: { scope: "settings_email" })

    assert_not harness.send(:restore_step_up_session_from_params!)
  end
end
