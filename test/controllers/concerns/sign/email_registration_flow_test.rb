# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::EmailRegistrationFlowTest < ActiveSupport::TestCase
  class Harness
    class << self
      def before_action(*) = nil

      def skip_before_action(*) = nil
    end

    include Sign::EmailRegistrationFlow

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

    def build_notice_params(message, _session_key = nil)
      { notice: message, rt: Base64.urlsafe_encode64("/configuration/emails") }
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

    safe_path = "/configuration/emails"
    params = { rt: Base64.urlsafe_encode64(safe_path) }

    harness.send(:sanitize_redirect_params!, params)

    assert_equal Base64.urlsafe_encode64(safe_path), params[:rt]

    params = { rt: Base64.urlsafe_encode64("https://evil.example") }
    harness.send(:sanitize_redirect_params!, params)

    assert_not params.key?(:rt)

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
    valid_email = Struct.new(:otp_expired?, :user_email_status_id).new(false, UserEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    expired_email = Struct.new(:otp_expired?, :user_email_status_id).new(true, UserEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    verified_email = Struct.new(:otp_expired?, :user_email_status_id).new(false, UserEmailStatus::VERIFIED)

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

    assert_instance_of UserEmail, harness.instance_variable_get(:@user_email)
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
    assert_equal ["/emails/new?rt=#{Base64.urlsafe_encode64("/configuration/emails")}"], harness.redirect_args
  end

  test "abstract path hooks raise not implemented" do
    harness = Harness.new

    assert_raises(NotImplementedError) { Sign::EmailRegistrationFlow.instance_method(:after_email_registration_started_path).bind_call(harness) }
    assert_raises(NotImplementedError) { Sign::EmailRegistrationFlow.instance_method(:after_email_registration_verified_path).bind_call(harness) }
  end
end
