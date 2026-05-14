# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::ComVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  VisitorStruct = Struct.new(:id, :public_id, :visitor_emails, :visitor_passkeys)

  class Harness
    include Sign::VerificationReauthSessionStore
    include Sign::ComVerificationBase::Overrides

    ALLOWED_SCOPES = Sign::AppVerificationBase::ALLOWED_SCOPES
    REAUTH_SESSION_KEY = Sign::AppVerificationBase::REAUTH_SESSION_KEY
    EMAIL_OTP_SESSION_KEY = Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY
    REAUTH_TTL = Sign::AppVerificationBase::REAUTH_TTL

    attr_accessor :visitor, :visitor_token, :params_hash, :redirect_args, :restore_result, :generated_hotp

    def initialize(visitor:, visitor_token: nil)
      @visitor = visitor
      @visitor_token = visitor_token
      @params_hash = {}
      @restore_result = false
      @generated_hotp = ["secret", 1, "123456"]
    end

    def current_visitor = visitor

    def actor_token = visitor_token

    def current_session_token = visitor_token

    def params = params_hash.with_indifferent_access

    def safe_internal_path(path)
      (path.to_s.start_with?("/") && !path.to_s.start_with?("//")) ? path : nil
    end

    def current_reauth_session
      visitor_token&.reauth_session
    end

    def restore_reauth_session_from_params!
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

    def generate_hotp_code
      generated_hotp
    end

    def email_otp_cache_key
      "reauth_session:#{current_reauth_session.id}:email_otp"
    end
  end

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "start_reauth_session stores a valid visitor session" do
    visitor = create_verified_visitor_with_email(email_address: "com-start-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)
    return_to = Base64.urlsafe_encode64("/configuration/emails/new")

    travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
      harness.send(:start_reauth_session!, scope: "configuration_email", return_to_param: return_to)

      session = token.reload.reauth_session

      assert_equal token.id, session.visitor_token_id
      assert_equal "configuration_email", session.scope
      assert_equal "/configuration/emails/new", session.return_to
      assert_in_delta 15.minutes.from_now, session.lapses_at, 1.second
    end
  end

  test "start_reauth_session rejects invalid return path and scope mismatch" do
    visitor = create_verified_visitor_with_email(email_address: "com-reject-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)

    assert_raises(ActionController::BadRequest) do
      harness.send(:start_reauth_session!, scope: "configuration_email", return_to_param: Base64.urlsafe_encode64("https://evil.example"))
    end

    assert_raises(ActionController::BadRequest) do
      harness.send(
        :start_reauth_session!, scope: "unknown",
                                return_to_param: Base64.urlsafe_encode64("/configuration/emails"),
      )
    end

    assert_raises(ActionController::BadRequest) do
      harness.send(
        :start_reauth_session!, scope: "configuration_email",
                                return_to_param: Base64.urlsafe_encode64("/configuration/secrets"),
      )
    end
  end

  test "valid_reauth_session checks expiry actor scope and return path" do
    visitor = create_verified_visitor_with_email(email_address: "com-valid-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    other_token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)

    valid_session = create_visitor_reauth_session(visitor_token: token)

    assert harness.send(:valid_reauth_session?, valid_session)
    assert_not harness.send(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.lapses_at = 1.minute.ago })
    assert_not harness.send(
      :valid_reauth_session?, valid_session.dup.tap { |rs|
                                rs.visitor_token_id = other_token.id
                              },
    )
    assert_not harness.send(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.scope = "" })
    assert_not harness.send(:valid_reauth_session?, valid_session.dup.tap { |rs| rs.return_to = "" })
  end

  test "handle_invalid_reauth_session clears cache and redirects when restore fails" do
    visitor = create_verified_visitor_with_email(email_address: "com-invalid-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor)
    harness = Harness.new(visitor: visitor, visitor_token: token)
    harness.params_hash = { ri: "jp" }
    reauth_session = create_visitor_reauth_session(visitor_token: token)
    Rails.cache.write("reauth_session:#{reauth_session.id}:email_otp", { "secret" => "old" })

    assert_not harness.send(:handle_invalid_reauth_session!)
    assert_nil Rails.cache.read("reauth_session:#{reauth_session.id}:email_otp")
    assert_match "/verification?", harness.redirect_args.first.first
  end

  test "com verification exposes visitor specific models and values" do
    visitor = VisitorStruct.new(42, "cust-public-id", [], [])
    passkey = Struct.new(:visitor_id).new(42)
    harness = Harness.new(visitor: visitor)
    harness.params_hash = { ri: "jp" }

    assert_equal :visitor_token_id, harness.send(:reauth_session_token_foreign_key)
    assert_equal "/verification?ri=jp", harness.send(:verification_unavailable_redirect_path)
    assert_equal VisitorVerification, harness.send(:verification_model)
    assert_equal UserChronicleEvent::STEP_UP_VERIFIED, harness.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.send(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.send(:verification_success_fallback_path)
    assert_equal UserChronicleEvent, harness.send(:verification_audit_event_class)
    assert_equal UserChronicleLevel, harness.send(:verification_audit_level_class)
    assert_equal UserChronicleLevel::NOTHING, harness.send(:verification_default_activity_level_id)
    assert_equal UserChronicle, harness.send(:verification_activity_model)
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
    reauth_session = create_visitor_reauth_session(visitor_token: token)

    assert harness.send(:send_email_otp!)
    assert_equal(
      { "secret" => "secret",
        "counter" => 1, },
      Rails.cache.read("reauth_session:#{reauth_session.id}:email_otp"),
    )
  end

  private

  def create_visitor_reauth_session(visitor_token:, scope: "configuration_email", return_to: "/configuration/emails")
    VisitorReauthSession.create!(
      visitor_token: visitor_token,
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
