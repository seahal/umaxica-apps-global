# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::AppVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users

  UserStruct = Struct.new(:id, :public_id, :user_passkeys, :user_one_time_passwords)

  class Harness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil

      def auth_required!(*) = nil

      def public_strict!(*) = nil
    end

    def verification_model = nil

    def verification_audit_event_class = nil

    def verification_audit_level_class = nil

    def verification_success_event_id = nil

    def verification_success_notice_key = nil

    def verification_success_fallback_path = nil

    def verification_activity_model = nil

    def verification_passkey_model = nil

    def verification_no_passkey_i18n_key = nil

    def verification_unavailable_redirect_path = "/verification?ri=jp"

    include Sign::AppVerificationBase

    attr_accessor :user, :user_token, :params_hash, :redirect_args, :hotp_result

    def initialize(user:, user_token: nil)
      @user = user
      @user_token = user_token
      @params_hash = {}
      @hotp_result = true
    end

    def current_user = user

    def actor_token = user_token

    def current_session_token = user_token

    def params = ActionController::Parameters.new(params_hash)

    def sign_app_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def sign_app_configuration_path(params = {})
      "/configuration?#{params.to_query}"
    end

    def sign_app_root_path(params = {})
      "/?#{params.to_query}"
    end

    def current_reauth_session
      user_token&.reauth_session
    end

    def start_reauth_session!(scope:, return_to_param:)
      Sign::VerificationReauthSessionStore.instance_method(:start_reauth_session!).bind_call(
        self,
        scope: scope,
        return_to_param: return_to_param,
      )
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

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "verification params and incoming redirect helpers prefer verification payload" do
    user = UserStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)
    return_to = Base64.urlsafe_encode64("/configuration/emails")
    harness.params_hash = {
      ri: "jp",
      scope: "configuration_secret",
      rt: Base64.urlsafe_encode64("/configuration/secrets"),
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
    user = users(:one)
    token = UserToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)

    assert_not harness.app_call(:email_otp_session_active?)

    reauth_session = create_user_reauth_session(user_token: token)
    Rails.cache.write("reauth_session:#{reauth_session.id}:email_otp", { "secret" => "secret" }, expires_in: 5.minutes)

    assert harness.app_call(:email_otp_session_active?)

    Rails.cache.delete("reauth_session:#{reauth_session.id}:email_otp")

    assert_not harness.app_call(:email_otp_session_active?)

    nonce = harness.app_call(:ensure_email_nonce!)

    assert_predicate nonce, :present?
    assert_equal nonce, harness.app_call(:ensure_email_nonce!)
    assert_equal "configuration_email", harness.app_call(:current_reauth_scope)
    assert_equal Base64.urlsafe_encode64("/configuration/emails"), harness.app_call(:current_reauth_return_to_param)
  end

  test "reauth session validation and restore from params" do
    user = users(:one)
    token = UserToken.create!(user: user)
    other_token = UserToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    valid_session = create_user_reauth_session(user_token: token)

    assert harness.app_call(:valid_reauth_session?, valid_session)
    assert_not harness.app_call(
      :valid_reauth_session?, valid_session.dup.tap { |rs|
                                rs.user_token_id = other_token.id
                              },
    )
    assert_not harness.app_call(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.lapses_at = 1.minute.ago })
    assert_not harness.app_call(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.scope = "" })
    assert_not harness.app_call(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.return_to = "" })

    return_to = Base64.urlsafe_encode64("/configuration/emails")
    harness.params_hash = { scope: "configuration_email", return_to: return_to }

    assert harness.app_call(:restore_reauth_session_from_params!)
    restored = token.reload.reauth_session

    assert_equal "configuration_email", restored.scope
    assert_equal "/configuration/emails", restored.return_to

    harness.params_hash = {}

    assert_not harness.app_call(:restore_reauth_session_from_params!)
  end

  test "invalid reauth session redirects and clears state" do
    user = users(:one)
    token = UserToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    harness.params_hash = { ri: "jp" }
    reauth_session = create_user_reauth_session(user_token: token)
    Rails.cache.write("reauth_session:#{reauth_session.id}:email_otp", { "secret" => "old" })

    assert_not harness.app_call(:handle_invalid_reauth_session!)
    assert_nil Rails.cache.read("reauth_session:#{reauth_session.id}:email_otp")
    assert_match "/configuration?", harness.redirect_args.first.first
  end

  test "app verification exposes user specific models and values" do
    passkey = Struct.new(:user_id).new(7)
    user = UserStruct.new(7, "user-public-id", [:passkey], [])
    harness = Harness.new(user: user)
    harness.params_hash = { ri: "jp" }

    assert_equal :user_token_id, harness.app_call(:reauth_session_token_foreign_key)
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
    user = users(:one)
    token = UserToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    reauth_session = create_user_reauth_session(user_token: token)

    harness.params_hash = { verification: { code: "abc" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが不正です"], harness.instance_variable_get(:@verification_errors)

    harness.params_hash = { verification: { code: "123456" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの再送信が必要です"], harness.instance_variable_get(:@verification_errors)

    Rails.cache.write(
      "reauth_session:#{reauth_session.id}:email_otp", {
        "secret" => "secret",
        "counter" => 1,
      },
    )
    reauth_session.update_columns(lapses_at: 1.minute.ago, purge_at: 1.minute.ago)

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの有効期限が切れました"], harness.instance_variable_get(:@verification_errors)

    reauth_session.update!(lapses_at: 5.minutes.from_now, purge_at: 5.minutes.from_now)
    harness.hotp_result = false

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが正しくありません"], harness.instance_variable_get(:@verification_errors)

    harness.hotp_result = true

    assert harness.app_call(:verify_email_otp!)
  end

  private

  def create_user_reauth_session(user_token:, scope: "configuration_email", return_to: "/configuration/emails")
    UserReauthSession.create!(
      user_token: user_token,
      scope: scope,
      return_to: return_to,
      method: nil,
      status: "PENDING",
      attempt_count: 0,
      lapses_at: 5.minutes.from_now,
      purge_at: 5.minutes.from_now,
    )
  end
end
