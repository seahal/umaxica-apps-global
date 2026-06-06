# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients

  ClientStruct = Struct.new(:id, :public_id, :client_passkeys, :client_totp_credentials)

  class Harness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil

      def declare_authentication_mode!(*, **) = nil
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

    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignAppVerificationBase

    attr_accessor :user, :user_token, :params_hash, :redirect_args, :hotp_result

    def initialize(user:, user_token: nil)
      @user = user
      @user_token = user_token
      @params_hash = {}
      @hotp_result = true
    end

    def current_client = user

    def actor_token = user_token

    def current_session_token = user_token

    def params = ActionController::Parameters.new(params_hash)

    def sign_app_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def sign_app_settings_path(params = {})
      "/settings?#{params.to_query}"
    end

    def signed_pt_to_safe_path(value)
      value.to_s.start_with?("/") ? value.to_s : nil
    end

    def issue_step_up_pt(value)
      "signed--#{value}"
    end

    def sign_app_root_path(params = {})
      "/?#{params.to_query}"
    end

    def current_step_up_session
      user_token&.step_up_session
    end

    def start_step_up_session!(scope:, pt_param:)
      SignVerificationStepUpSessionStore.instance_method(:start_step_up_session!).bind_call(
        self,
        scope: scope,
        pt_param: pt_param,
      )
    end

    def safe_redirect_to(*args, **kwargs)
      self.redirect_args = [args, kwargs]
    end

    def verify_hotp_code(secret_credential:, counter:, pass_code:)
      hotp_result && secret_credential == "secret_credential" && counter == 1 && pass_code == "123456"
    end

    def app_call(method_name, ...)
      SignAppVerificationBase.instance_method(method_name).bind_call(self, ...)
    end

    def clear_step_up_state!
      app_call(:clear_step_up_state!)
    end

    def restore_step_up_session_from_params!
      app_call(:restore_step_up_session_from_params!)
    end

    def valid_step_up_session?(rs)
      app_call(:valid_step_up_session?, rs)
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
    user = ClientStruct.new(7, "user-public-id", [], [])
    harness = Harness.new(user: user)
    return_to = "/settings/emails"
    harness.params_hash = {
      ri: "jp",
      scope: "settings_secret_credential",
      pt: "/settings/secret_credentials",
      verification: {
        scope: "settings_email",
        return_to: return_to,
        ignored: "value",
      },
    }

    assert_equal "settings_email", harness.send(:incoming_scope)
    assert_equal "/settings/secret_credentials", harness.send(:incoming_pt)
    assert_equal(
      { ri: "jp", scope: "settings_email", pt: "/settings/secret_credentials" },
      harness.send(:verification_recovery_redirect_params),
    )
    assert_equal %w(scope), harness.app_call(:verification_params).keys
  end

  test "email otp session active and nonce helpers use step_up session" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)

    assert_not harness.app_call(:email_otp_session_active?)

    step_up_session = create_user_step_up_session(user_token: token)
    Rails.cache.write(
      "step_up_session:#{step_up_session.id}:email_otp", { "secret_credential" => "secret_credential" },
      expires_in: 5.minutes,
    )

    assert harness.app_call(:email_otp_session_active?)

    Rails.cache.delete("step_up_session:#{step_up_session.id}:email_otp")

    assert_not harness.app_call(:email_otp_session_active?)

    nonce = harness.app_call(:ensure_email_nonce!)

    assert_predicate nonce, :present?
    assert_equal nonce, harness.app_call(:ensure_email_nonce!)
    assert_equal "settings_email", harness.app_call(:current_step_up_scope)
    assert_match(/--/, harness.app_call(:current_step_up_pt_param))
  end

  test "step_up session validation and restore from params" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    other_token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    valid_session = create_user_step_up_session(user_token: token)

    assert harness.app_call(:valid_step_up_session?, valid_session)
    assert_not harness.app_call(
      :valid_step_up_session?, valid_session.dup.tap { |rs|
                                 rs.user_token_id = other_token.id
                               },
    )
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.discarded_at = 1.minute.ago })
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.scope = "" })
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.return_to = "" })

    return_to = "/settings/emails"
    harness.params_hash = { scope: "settings_email", return_to: return_to }

    assert_not harness.app_call(:restore_step_up_session_from_params!)

    harness.params_hash = {}

    assert_not harness.app_call(:restore_step_up_session_from_params!)
  end

  test "invalid step_up session redirects and clears state" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    harness.params_hash = { ri: "jp" }
    step_up_session = create_user_step_up_session(user_token: token)
    Rails.cache.write("step_up_session:#{step_up_session.id}:email_otp", { "secret_credential" => "old" })

    assert_not harness.app_call(:handle_invalid_step_up_session!)
    assert_nil Rails.cache.read("step_up_session:#{step_up_session.id}:email_otp")
    assert_match "/settings?", harness.redirect_args.first.first
  end

  test "app verification exposes user specific models and values" do
    passkey = Struct.new(:user_id).new(7)
    user = ClientStruct.new(7, "user-public-id", [:passkey], [])
    harness = Harness.new(user: user)
    harness.params_hash = { ri: "jp" }

    assert_equal :user_token_id, harness.app_call(:step_up_session_token_foreign_key)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_unavailable_redirect_path)
    assert_equal ClientVerification, harness.app_call(:verification_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, harness.app_call(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.app_call(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_success_fallback_path)
    assert_equal ClientChronicleEvent, harness.app_call(:verification_audit_event_class)
    assert_equal ClientChronicleLevel, harness.app_call(:verification_audit_level_class)
    assert_equal ClientChronicleLevel::NOTHING, harness.app_call(:verification_default_activity_level_id)
    assert_equal ClientChronicle, harness.app_call(:verification_activity_model)
    assert_equal user, harness.app_call(:current_verification_actor)
    assert_equal "Client", harness.app_call(:verification_actor_type)
    assert_equal [:passkey], harness.app_call(:verification_passkeys_scope)
    assert_equal ClientPasskey, harness.app_call(:verification_passkey_model)
    assert harness.app_call(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.app_call(:verification_no_passkey_i18n_key)
  end

  test "verify_email_otp handles invalid missing expired wrong and valid codes" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    step_up_session = create_user_step_up_session(user_token: token)

    harness.params_hash = { verification: { code: "abc" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが不正です"], harness.instance_variable_get(:@verification_errors)

    harness.params_hash = { verification: { code: "123456" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの再送信が必要です"], harness.instance_variable_get(:@verification_errors)

    Rails.cache.write(
      "step_up_session:#{step_up_session.id}:email_otp", {
        "secret_credential" => "secret_credential",
        "counter" => 1,
      },
    )
    step_up_session.update_columns(discarded_at: 1.minute.ago, purged_at: 1.minute.ago)

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの有効期限が切れました"], harness.instance_variable_get(:@verification_errors)

    step_up_session.update!(discarded_at: 5.minutes.from_now, purged_at: 5.minutes.from_now)
    harness.hotp_result = false

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが正しくありません"], harness.instance_variable_get(:@verification_errors)

    harness.hotp_result = true

    assert harness.app_call(:verify_email_otp!)
  end

  private

  def create_user_step_up_session(user_token:, scope: "settings_email", return_to: "/settings/emails")
    ClientStepUpSession.create!(
      user_token: user_token,
      scope: scope,
      return_to: return_to,
      method: nil,
      status: "PENDING",
      attempt_count: 0,
      discarded_at: 5.minutes.from_now,
      purged_at: 5.minutes.from_now,
    )
  end
end
