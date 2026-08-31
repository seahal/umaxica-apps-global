# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignEmailRegistrationFlowTest < ActiveSupport::TestCase
  class Harness
    class << self
      def before_action(*) = nil

      def skip_before_action(*) = nil
    end

    include SignEmailRegistrable
    include SignEmailRegistrationFlow
    include EnforcementIdentifierGate

    attr_accessor :session_hash, :flash_hash, :reset_called, :target_user, :params_hash, :render_args, :redirect_args

    def initialize
      @session_hash = {}
      @flash_hash = {}
      @reset_called = false
      @params_hash = {}
    end

    def session = session_hash

    def flash = flash_hash

    def params = ActionController::Parameters.new(params_hash)

    def safe_internal_path(path)
      (path.to_s.start_with?("/") && !path.to_s.start_with?("//")) ? path : nil
    end

    def signed_pt_token(value)
      safe_path = safe_internal_path(value)
      safe_path ? "signed:#{safe_path}" : nil
    end

    def path_from_signed_pt(token)
      token.to_s.start_with?("signed:") ? token.delete_prefix("signed:") : nil
    end

    def build_notice_params(message, _session_key = nil)
      { notice: message, pt: signed_pt_token("/settings/emails") }
    end

    def reset_email_flow!
      self.reset_called = true
    end

    def t(...)
      I18n.t(...)
    end

    def new_email_registration_path(params = {})
      "/emails/new?#{params.to_query}"
    end

    def auth_app_settings_emails_url(**params)
      query = params.to_query
      query.present? ? "/settings/emails?#{query}" : "/settings/emails"
    end

    def cross_host_redirect_allowed?
      false
    end

    def email_registration_target_user
      target_user
    end

    def verify_email_registration_turnstile!(...)
      true
    end

    def initiate_email_verification!(*)
      false
    end

    def render(*args, **kwargs)
      self.render_args = [*args, kwargs]
    end

    def redirect_to(*args, **kwargs)
      self.redirect_args = [*args, kwargs].reject(&:empty?)
    end
  end

  test "sanitize redirect params keeps safe redirect and removes unsafe values" do
    harness = Harness.new
    empty_params = {}

    harness.send(:sanitize_redirect_params!, empty_params)

    assert_empty empty_params

    safe_path = "/settings/emails"
    params = { pt: safe_path }

    harness.send(:sanitize_redirect_params!, params)

    assert_equal "signed:#{safe_path}", params[:pt]

    params = { pt: "https://evil.example" }
    harness.send(:sanitize_redirect_params!, params)

    assert_not params.key?(:pt)

    assert_nil harness.send(:sanitize_encoded_redirect, "")
    assert_nil harness.send(:sanitize_encoded_redirect, "not-base64%%%")
  end

  test "reset and notice path clear session and preserve safe redirect" do
    harness = Harness.new
    harness.session_hash[harness.send(:registration_email_session_key)] = "email-public-id"

    harness.send(:reset_email_registration_flow!)

    assert_nil harness.session_hash[harness.send(:registration_email_session_key)]
    assert_predicate harness, :reset_called

    path = harness.send(:new_registration_path_with_notice)

    assert_match "/emails/new?", path
    assert_equal I18n.t("sign.app.registration.email.edit.session_expired"), harness.flash_hash[:notice]
  end

  test "valid registration email session checks presence expiry and status" do
    harness = Harness.new
    valid_email = Struct.new(:otp_expired?, :user_email_status_id).new(false, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    expired_email = Struct.new(:otp_expired?, :user_email_status_id).new(true, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    verified_email = Struct.new(:otp_expired?, :user_email_status_id).new(false, ClientEmailStatus::VERIFIED)

    assert_not harness.send(:valid_registration_email_session?)

    harness.instance_variable_set(:@user_email, valid_email)

    assert harness.send(:valid_registration_email_session?)

    harness.instance_variable_set(:@user_email, expired_email)

    assert_not harness.send(:valid_registration_email_session?)

    harness.instance_variable_set(:@user_email, verified_email)

    assert_not harness.send(:valid_registration_email_session?)
  end

  test "new initializes user email and current registration email returns nil without target" do
    harness = Harness.new

    harness.new

    assert_instance_of ClientEmail, harness.instance_variable_get(:@user_email)
    assert_nil harness.send(:current_registration_email)
    assert_nil harness.send(:on_email_registration_verified!)
  end

  test "create renders new when verification cannot be initiated" do
    harness = Harness.new
    harness.params_hash = {
      user_email: {
        raw_address: "failed-registration@example.com",
        confirm_policy: "1",
      },
    }

    harness.create

    assert_equal [:new, { status: :unprocessable_content }], harness.render_args
  end

  test "update redirects to new registration path when session is invalid" do
    harness = Harness.new
    harness.params_hash = { user_email: { pass_code: "123456" } }

    harness.update

    assert_predicate harness, :reset_called
    assert_equal ["/emails/new?pt=signed%3A%2Fsettings%2Femails"], harness.redirect_args
  end

  test "abstract path hooks raise not implemented" do
    harness = Harness.new

    assert_raises(NotImplementedError) {
      SignEmailRegistrationFlow.instance_method(:after_email_registration_started_path).bind_call(harness)
    }
    assert_raises(NotImplementedError) {
      SignEmailRegistrationFlow.instance_method(:after_email_registration_verified_path).bind_call(harness)
    }
    assert_raises(NotImplementedError) {
      SignEmailRegistrationFlow.instance_method(:email_registration_target_user).bind_call(harness)
    }
    assert_raises(NotImplementedError) {
      SignEmailRegistrationFlow.instance_method(:new_email_registration_path).bind_call(harness)
    }
  end

  test "update renders the edit screen when turnstile stealth validation fails" do
    harness = Harness.new
    flash = Object.new
    now_store = {}
    flash.define_singleton_method(:now) { now_store }
    flash.define_singleton_method(:[]=) { |key, value|
      instance_variable_set(:@store, (instance_variable_get(:@store) || {}).merge(key => value))
    }
    flash.define_singleton_method(:[]) { |key| (instance_variable_get(:@store) || {})[key] }
    harness.flash_hash = flash
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    harness.define_singleton_method(:valid_registration_email_session?) { true }
    harness.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => false } }

    harness.update

    assert_equal [:edit, { status: :unprocessable_content }], harness.render_args
    assert_equal I18n.t("turnstile_error"), now_store[:alert]
  end

  test "resend redirects away unless the registration email is resendable" do
    harness = Harness.new

    harness.resend

    assert_predicate harness, :reset_called
    assert_equal ["/emails/new?pt=signed%3A%2Fsettings%2Femails"], harness.redirect_args
  end

  test "resend redirects with a too-soon notice while the otp cooldown is active" do
    harness = Harness.new
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.define_singleton_method(:locked?) { false }
    pending.define_singleton_method(:otp_cooldown_active?) { true }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    harness.define_singleton_method(:after_email_registration_started_path) { |params = {}|
      "/emails/edit?#{params.to_query}"
    }
    harness.define_singleton_method(:build_redirect_params) { |key, message, _session_key| { key => message } }

    harness.resend

    assert_match %r{\A/emails/edit\?}, harness.redirect_args.first
    assert_equal I18n.t("otp.resend.too_soon"), harness.flash_hash[:alert]
  end

  test "resend generates an otp and redirects with a sent notice" do
    harness = Harness.new
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.define_singleton_method(:locked?) { false }
    pending.define_singleton_method(:otp_cooldown_active?) { false }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    generated = []
    sent = []
    harness.define_singleton_method(:generate_otp_for) { |email| generated << email; "654321" }
    harness.define_singleton_method(:send_verification_email) { |code| sent << code }
    harness.define_singleton_method(:after_email_registration_started_path) { |params = {}|
      "/emails/edit?#{params.to_query}"
    }
    harness.define_singleton_method(:build_redirect_params) { |key, message, _session_key| { key => message } }

    harness.resend

    assert_equal [pending], generated
    assert_equal ["654321"], sent
    assert_equal I18n.t("otp.resend.sent"), harness.flash_hash[:notice]
  end

  test "complete_registration_verification! resets the flow when the email is locked" do
    harness = Harness.new
    harness.instance_variable_set(:@user_email, ClientEmail.new(public_id: "email-public-id"))
    harness.define_singleton_method(:complete_email_verification!) { |*| :locked }

    result = harness.send(:complete_registration_verification!, "000000")

    assert_not result
    assert_predicate harness, :reset_called
    assert_equal I18n.t("sign.app.registration.email.update.attempts_exceeded"), harness.flash_hash[:alert]
    assert_equal ["/emails/new?"], harness.redirect_args
  end

  test "complete_registration_verification! re-renders edit when verification fails" do
    harness = Harness.new
    harness.instance_variable_set(:@user_email, ClientEmail.new(public_id: "email-public-id"))
    harness.define_singleton_method(:complete_email_verification!) { |*| false }

    result = harness.send(:complete_registration_verification!, "000000")

    assert_not result
    assert_equal [:edit, { status: :unprocessable_content }], harness.render_args
  end

  test "email_registration_params permits a plain hash payload" do
    harness = Harness.new
    harness.params_hash = { client_email: { address: "plain@example.com", extra: "drop" } }

    permitted = harness.send(:email_registration_params, :address)

    assert_equal "plain@example.com", permitted[:address]
    assert_not permitted.key?(:extra)
  end

  test "email_registration_return_path uses the signed pt token when present" do
    harness = Harness.new
    harness.define_singleton_method(:retrieve_pt) { |_key| "signed:/settings/emails" }

    assert_equal "/settings/emails", harness.send(:email_registration_return_path, "/fallback")
    harness.define_singleton_method(:retrieve_pt) { |_key| nil }

    assert_equal "/fallback", harness.send(:email_registration_return_path, "/fallback")
  end
end
