# typed: false
# frozen_string_literal: true

require "test_helper"

# Re-entering the email step-up while a code is still live must not send a
# second code: the visitor is taken straight to the code page for the code that
# is already outstanding, which is what makes the resend endpoint the only way
# to ask for another one.
class AuthComVerificationEmailsResendGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Com::Verification::EmailsController
    attr_accessor :params_hash, :redirected

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def require_step_up_session! = true

    def redirect_if_recent_verification_for_get! = false

    def require_method_available!(_method) = true

    def email_otp_session_active? = true

    def ensure_email_nonce! = "nonce-1"

    def current_step_up_scope_param = "settings_email"

    def current_step_up_pt_param = "signed-pt"

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  test "a live code takes the visitor to the code page instead of sending another" do
    harness = Harness.new
    harness.params_hash = { ri: "jp" }
    harness.request = ActionDispatch::TestRequest.create

    harness.new

    assert_includes harness.redirected.first.first, "nonce-1"
  end
end
