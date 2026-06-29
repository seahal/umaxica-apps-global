# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SignComVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  VisitorStruct = Struct.new(:id, :public_id, :visitor_emails, :visitor_passkeys)

  class Harness
    include SignVerificationStepUpSessionStore
    include SignEmailOtpVerificationSupport
    include SignComVerificationBase::Overrides

    ALLOWED_SCOPES = SignComVerificationBase::ALLOWED_SCOPES
    STEP_UP_TTL = SignComVerificationBase::STEP_UP_TTL
    EMAIL_OTP_RESEND_COOLDOWN = SignEmailOtpVerificationSupport::EMAIL_OTP_RESEND_COOLDOWN

    attr_accessor :visitor, :visitor_token, :params_hash, :redirect_args, :restore_result, :generated_hotp,
                  :session_hash

    def initialize(visitor:, visitor_token: nil)
      @visitor = visitor
      @visitor_token = visitor_token
      @params_hash = {}
      @restore_result = false
      @generated_hotp = ["secret_credential", 1, "123456"]
      @session_hash = {}
    end

    def current_visitor = visitor

    def actor_token = visitor_token

    def current_session_token = visitor_token

    def params = params_hash.with_indifferent_access

    def session = session_hash

    def safe_internal_path(path)
      (path.to_s.start_with?("/") && !path.to_s.start_with?("//")) ? path : nil
    end

    def current_step_up_session
      visitor_token&.step_up_session
    end

    def restore_step_up_session_from_params!
      restore_result
    end

    def verification_recovery_redirect_params
      { ri: params[:ri] }
    end

    def safe_redirect_to(*args, **kwargs)
      self.redirect_args = [args, kwargs]
    end

    def sign_com_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def auth_com_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def generate_hotp_code
      generated_hotp
    end
  end

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "start_step_up_session stores a valid visitor session" do
    visitor = create_verified_visitor_with_email(email_address: "com-start-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)
    return_to = "/settings/emails/new"

    travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
      harness.send(:start_step_up_session!, scope: "settings_email", pt_param: return_to)

      session = token.reload.step_up_session

      assert_equal token.id, session.visitor_token_id
      assert_equal "settings_email", session.scope
      assert_equal "/settings/emails/new", session.return_to
      assert_in_delta 15.minutes.from_now, session.discarded_at, 1.second
    end
  end

  test "start_step_up_session rejects invalid return path and scope mismatch" do
    visitor = create_verified_visitor_with_email(email_address: "com-reject-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)

    assert_raises(ActionController::BadRequest) do
      harness.send(:start_step_up_session!, scope: "settings_email", pt_param: "https://evil.example")
    end

    assert_raises(ActionController::BadRequest) do
      harness.send(
        :start_step_up_session!, scope: "unknown",
                                 pt_param: "/settings/emails",
      )
    end

    assert_raises(ActionController::BadRequest) do
      harness.send(
        :start_step_up_session!, scope: "settings_email",
                                 pt_param: "/settings/secrets",
      )
    end
  end

  test "valid_step_up_session checks expiry actor scope and return path" do
    visitor = create_verified_visitor_with_email(email_address: "com-valid-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    other_token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)

    valid_session = create_visitor_step_up_session(visitor_token: token)

    assert harness.send(:valid_step_up_session?, valid_session)
    assert_not harness.send(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.discarded_at = 1.minute.ago })
    assert_not harness.send(
      :valid_step_up_session?, valid_session.dup.tap { |rs|
                                 rs.visitor_token_id = other_token.id
                               },
    )
    assert_not harness.send(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.scope = "" })
    assert_not harness.send(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.return_to = "" })
  end

  test "handle_invalid_step_up_session clears session state and redirects when restore fails" do
    visitor = create_verified_visitor_with_email(email_address: "com-invalid-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)
    harness.params_hash = { ri: "jp" }
    create_visitor_step_up_session(visitor_token: token)
    harness.send(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.send(:email_otp_digest, "123456") },
    )

    assert_not harness.send(:handle_invalid_step_up_session!)
    assert_nil harness.session[:sign_step_up_email_otp]
    assert_match "/verification?", harness.redirect_args.first.first
  end

  test "com verification exposes visitor specific models and values" do
    visitor = VisitorStruct.new(42, "cust-public-id", [], [])
    passkey = Struct.new(:visitor_id).new(42)
    harness = Harness.new(visitor: visitor)
    harness.params_hash = { ri: "jp" }

    assert_equal :visitor_token_id, harness.send(:step_up_session_token_foreign_key)
    assert_equal "/verification?ri=jp", harness.send(:verification_unavailable_redirect_path)
    assert_equal VisitorVerification, harness.send(:verification_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, harness.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.send(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.send(:verification_success_fallback_path)
    assert_equal ClientChronicleEvent, harness.send(:verification_audit_event_class)
    assert_equal ClientChronicleLevel, harness.send(:verification_audit_level_class)
    assert_equal ClientChronicleLevel::NOTHING, harness.send(:verification_default_activity_level_id)
    assert_equal ClientChronicle, harness.send(:verification_activity_model)
    assert_equal visitor, harness.send(:current_verification_actor)
    assert_equal "Visitor", harness.send(:verification_actor_type)
    assert_equal :visitor_token_id, harness.send(:verification_token_foreign_key)
    assert_equal [], harness.send(:verification_passkeys_scope)
    assert_equal VisitorPasskey, harness.send(:verification_passkey_model)
    assert harness.send(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.send(:verification_no_passkey_i18n_key)
    assert_equal %i(email_otp passkey), harness.send(:step_up_supported_methods)
  end

  test "send_email_otp records session data and handles missing verified email" do
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      ensure_visitor_token_reference_records!
    end

    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)

    assert_not harness.send(:send_email_otp!)
    assert_equal ["メールアドレスが未確認です"], harness.instance_variable_get(:@verification_errors)

    VisitorEmail.create!(
      visitor: visitor,
      address: "com-verification-otp@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    step_up_session = create_visitor_step_up_session(visitor_token: token)

    assert harness.send(:send_email_otp!)
    payload = harness.session.fetch(:sign_step_up_email_otp)

    assert_equal step_up_session.id, payload.fetch("step_up_session_id")
    assert_equal harness.send(:email_otp_digest, "123456"), payload.fetch("otp_digest")
  end

  private

  def create_visitor_step_up_session(visitor_token:, scope: "settings_email", return_to: "/settings/emails")
    VisitorStepUpSession.create!(
      visitor_token: visitor_token,
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
