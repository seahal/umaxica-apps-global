# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::AppVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  UserStruct = Struct.new(:id, :public_id, :user_passkeys, :user_one_time_passwords)

  class Harness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil
    end

    include Sign::AppVerificationBase

    attr_accessor :user, :params_hash, :session_hash, :redirect_args, :started_reauth_session, :hotp_result

    def initialize(user:)
      @user = user
      @params_hash = {}
      @session_hash = {}
      @hotp_result = true
    end

    def current_user = user

    def session = session_hash

    def params = ActionController::Parameters.new(params_hash)

    def sign_app_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def current_reauth_session
      session[Sign::AppVerificationBase::REAUTH_SESSION_KEY]
    end

    def start_reauth_session!(scope:, return_to_param:)
      self.started_reauth_session = { scope: scope, return_to_param: return_to_param }
      session[Sign::AppVerificationBase::REAUTH_SESSION_KEY] = {
        "user_id" => current_user.id,
        "scope" => scope,
        "return_to" => Base64.urlsafe_decode64(return_to_param),
        "expires_at" => 5.minutes.from_now.to_i,
      }
    end

    def safe_redirect_to(*args, **kwargs)
      self.redirect_args = [args, kwargs]
    end

    def verify_hotp_code(secret:, counter:, pass_code:)
      hotp_result && secret == "secret" && counter == 1 && pass_code == "123456"
    end

    def app_call(method_name, ...)
      Sign::AppVerificationBase.instance_method(method_name).bind_call(self, ...)
    end

    def clear_reauth_state!
      app_call(:clear_reauth_state!)
    end

    def restore_reauth_session_from_params!
      app_call(:restore_reauth_session_from_params!)
    end

    def valid_reauth_session?(rs)
      app_call(:valid_reauth_session?, rs)
    end
  end

  test "verification params and incoming redirect helpers prefer verification payload" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)
    return_to = Base64.urlsafe_encode64("/configuration/emails")
    harness.params_hash = {
      ri: "jp",
      scope: "configuration_secret",
      rd: Base64.urlsafe_encode64("/configuration/secrets"),
      verification: {
        scope: "configuration_email",
        return_to: return_to,
        ignored: "value",
      },
    }

    assert_equal "configuration_email", harness.send(:incoming_scope)
    assert_equal return_to, harness.send(:incoming_return_to)
    assert_equal(
      { ri: "jp", scope: "configuration_email", return_to: return_to },
      harness.send(:verification_recovery_redirect_params),
    )
    assert_equal %w(scope return_to), harness.app_call(:verification_params).keys
  end

  test "email otp session active and nonce helpers use reauth session" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)

    assert_not harness.app_call(:email_otp_session_active?)

    harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY] = { "expires_at" => 5.minutes.from_now.to_i }

    assert harness.app_call(:email_otp_session_active?)

    harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY] = { "expires_at" => 1.minute.ago.to_i }

    assert_not harness.app_call(:email_otp_session_active?)

    harness.session_hash[Sign::AppVerificationBase::REAUTH_SESSION_KEY] = {
      "user_id" => 7,
      "scope" => "configuration_email",
      "return_to" => "/configuration/emails",
      "expires_at" => 5.minutes.from_now.to_i,
    }

    nonce = harness.app_call(:ensure_email_nonce!)

    assert_predicate nonce, :present?
    assert_equal nonce, harness.app_call(:ensure_email_nonce!)
    assert_equal "configuration_email", harness.app_call(:current_reauth_scope)
    assert_equal Base64.urlsafe_encode64("/configuration/emails"), harness.app_call(:current_reauth_return_to_param)
  end

  test "reauth session validation and restore from params" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)
    valid_session = {
      "user_id" => 7,
      "scope" => "configuration_email",
      "return_to" => "/configuration/emails",
      "expires_at" => 5.minutes.from_now.to_i,
    }

    assert harness.app_call(:valid_reauth_session?, valid_session)
    assert_not harness.app_call(:valid_reauth_session?, valid_session.merge("user_id" => 8))
    assert_not harness.app_call(:valid_reauth_session?, valid_session.merge("expires_at" => 1.minute.ago.to_i))
    assert_not harness.app_call(:valid_reauth_session?, valid_session.merge("scope" => ""))
    assert_not harness.app_call(:valid_reauth_session?, valid_session.merge("return_to" => ""))

    return_to = Base64.urlsafe_encode64("/configuration/emails")
    harness.params_hash = { scope: "configuration_email", return_to: return_to }

    assert harness.app_call(:restore_reauth_session_from_params!)
    assert_equal({ scope: "configuration_email", return_to_param: return_to }, harness.started_reauth_session)

    harness.params_hash = {}

    assert_not harness.app_call(:restore_reauth_session_from_params!)
  end

  test "invalid reauth session redirects and clears state" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)
    harness.params_hash = { ri: "jp" }
    harness.session_hash[Sign::AppVerificationBase::REAUTH_SESSION_KEY] = { "user_id" => 7 }
    harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY] = { "secret" => "old" }

    assert_not harness.app_call(:handle_invalid_reauth_session!)
    assert_nil harness.session_hash[Sign::AppVerificationBase::REAUTH_SESSION_KEY]
    assert_nil harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY]
    assert_match "/verification?", harness.redirect_args.first.first
  end

  test "app verification exposes user specific models and values" do
    passkey = Struct.new(:user_id).new(7)
    user = UserStruct.new(7, "user-public-id", [:passkey], [])
    harness = Harness.new(user: user)
    harness.params_hash = { ri: "jp" }

    assert_equal 7, harness.app_call(:reauth_actor_id)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_unavailable_redirect_path)
    assert_equal UserVerification, harness.app_call(:verification_model)
    assert_equal UserChronicleEvent::STEP_UP_VERIFIED, harness.app_call(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.app_call(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_success_fallback_path)
    assert_equal UserChronicleEvent, harness.app_call(:verification_audit_event_class)
    assert_equal UserChronicleLevel, harness.app_call(:verification_audit_level_class)
    assert_equal UserChronicleLevel::NOTHING, harness.app_call(:verification_default_activity_level_id)
    assert_equal UserChronicle, harness.app_call(:verification_activity_model)
    assert_equal user, harness.app_call(:current_verification_actor)
    assert_equal "User", harness.app_call(:verification_actor_type)
    assert_equal [:passkey], harness.app_call(:verification_passkeys_scope)
    assert_equal UserPasskey, harness.app_call(:verification_passkey_model)
    assert harness.app_call(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.app_call(:verification_no_passkey_i18n_key)
  end

  test "verify_email_otp handles invalid missing expired wrong and valid codes" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)

    harness.params_hash = { verification: { code: "abc" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが不正です"], harness.instance_variable_get(:@verification_errors)

    harness.params_hash = { verification: { code: "123456" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの再送信が必要です"], harness.instance_variable_get(:@verification_errors)

    harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY] = {
      "secret" => "secret",
      "counter" => 1,
      "expires_at" => 1.minute.ago.to_i,
    }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの有効期限が切れました"], harness.instance_variable_get(:@verification_errors)

    harness.session_hash[Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY]["expires_at"] = 5.minutes.from_now.to_i
    harness.hotp_result = false

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが正しくありません"], harness.instance_variable_get(:@verification_errors)

    harness.hotp_result = true

    assert harness.app_call(:verify_email_otp!)
  end
end
