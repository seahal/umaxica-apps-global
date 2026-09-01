# typed: false
# frozen_string_literal: true

require "test_helper"

# The step-up OTP resend cooldown and the two preference-refresh failure arms are
# small, shared, and easy to get wrong in a way no ceremony test would notice:
# a cooldown that never expires locks the person out, and a refresh failure that
# does not answer nil lets a rejected token keep travelling.
class OtpResendAndRefreshFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class OtpHarness
    include SignEmailOtpVerificationSupport

    attr_accessor :session_hash, :otp_session

    def initialize
      @session_hash = {}
      @otp_session = nil
    end

    def session = @session_hash

    def email_otp_session_key = :email_otp

    def current_email_otp_session_data = otp_session

    def write_email_otp_session_data!(data) = self.otp_session = data

    def invoke(name, ...) = send(name, ...)
  end

  class RefreshHarness
    include PreferenceRefreshTokenTransport

    attr_reader :failed, :denied

    def handle_preference_refresh_failed(pref, id) = @failed = [pref, id]

    def handle_preference_refresh_binding_denied(pref, id) = @denied = [pref, id]

    def invoke(name, ...) = send(name, ...)
  end

  test "the email OTP resend cooldown blocks only until the stamped moment passes" do
    harness = OtpHarness.new

    assert_not harness.invoke(:email_otp_resend_rate_limited?), "no stamp means no cooldown"

    harness.invoke(:stamp_email_otp_resend!)

    assert harness.invoke(:email_otp_resend_rate_limited?)

    travel StepUpCooldowns::WINDOWS.fetch(:email_otp) + 1.second do
      assert_not harness.invoke(:email_otp_resend_rate_limited?)
    end
  end

  test "clearing the step-up state drops only the OTP entry and answers nil" do
    harness = OtpHarness.new
    harness.session_hash = { email_otp: "state", other: "kept" }

    assert_nil harness.invoke(:clear_and_return_nil_email_otp_session)
    assert_equal({ other: "kept" }, harness.session_hash)
  end

  test "a rejected preference refresh reports the failure and answers nil" do
    harness = RefreshHarness.new

    assert_nil harness.invoke(:handle_invalid_refresh_digest, :pref, "public-1")
    assert_equal [:pref, "public-1"], harness.failed

    assert_nil harness.invoke(:handle_denied_refresh_binding, :pref, "public-2")
    assert_equal [:pref, "public-2"], harness.denied
  end
end
