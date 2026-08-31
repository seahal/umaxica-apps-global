# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthComVerificationBaseControllerCoverageTest < ActiveSupport::TestCase
  class Harness < Auth::Com::Verification::BaseController
    def initialize
      @session_hash = {}
      @params_hash = { ri: "tokyo" }
      @redirect_args = nil
    end

    def session = @session_hash

    def params = ActionController::Parameters.new(@params_hash)

    attr_accessor :visitor, :token, :otp_session, :delivered, :hotp, :restore_ok

    def current_visitor = visitor

    def actor_token = token

    def current_email_otp_session_data
      otp_session
    end

    def write_email_otp_session_data!(data)
      self.otp_session = data
    end

    def generate_hotp_code
      hotp || ["secret", 1, "123456"]
    end

    def email_otp_digest(code)
      "digest-#{code}"
    end

    def email_otp_session_key
      :email_otp
    end

    def step_up_session_storage_available?
      true
    end

    def restore_step_up_session_from_params!
      restore_ok
    end

    def current_step_up_session
      token&.step_up_session
    end

    def verification_recovery_redirect_params
      { ri: params[:ri] }
    end

    def safe_redirect_to(*args, **kwargs)
      @redirect_args = [args, kwargs]
    end

    attr_reader :redirect_args

    def auth_com_verification_path(*args, **kwargs)
      query = args.first.is_a?(Hash) ? args.first : kwargs
      "/verification?#{query.to_query}"
    end
  end

  test "valid_step_up_session? requires a pending live visitor session" do
    harness = Harness.new
    token = Struct.new(:id).new(11)
    harness.token = token
    valid = Struct.new(:discarded_at, :visitor_token_id, :status, :scope, :return_to).new(
      1.minute.from_now, 11, "PENDING", "settings", "/return",
    )

    assert harness.send(:valid_step_up_session?, valid)
    assert_not harness.send(:valid_step_up_session?, nil)
    assert_not harness.send(
      :valid_step_up_session?,
      Struct.new(:discarded_at, :visitor_token_id, :status, :scope, :return_to).new(
        1.minute.ago, 11, "PENDING", "settings", "/return",
      ),
    )
  end

  test "handle_invalid_step_up_session! restores a valid session or redirects" do
    harness = Harness.new
    harness.restore_ok = false
    harness.token = Struct.new(:id, :step_up_session).new(11, nil)

    assert_equal false, harness.send(:handle_invalid_step_up_session!)
    assert_nil harness.session[:email_otp]
    assert harness.redirect_args

    restored = Struct.new(:discarded_at, :visitor_token_id, :status, :scope, :return_to).new(
      1.minute.from_now, 11, "PENDING", "settings", "/return",
    )
    harness.token = Struct.new(:id, :step_up_session).new(11, restored)
    harness.restore_ok = true
    harness.instance_variable_set(:@redirect_args, nil)

    assert harness.send(:handle_invalid_step_up_session!)
    assert_nil harness.redirect_args
  end

  test "verification mapping helpers name the visitor surface" do
    harness = Harness.new
    visitor = Struct.new(:id, :visitor_passkeys).new(5, :passkeys)
    harness.visitor = visitor
    passkey = Struct.new(:visitor_id).new(5)

    assert_equal VisitorStepUpSession, harness.send(:step_up_session_model)
    assert_equal :visitor_token_id, harness.send(:step_up_session_token_foreign_key)
    assert_equal "auth/com/application", harness.send(:step_up_handoff_layout)
    assert_equal VisitorVerification, harness.send(:verification_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, harness.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.send(:verification_success_notice_key)
    assert_equal ClientChronicleEvent, harness.send(:verification_audit_event_class)
    assert_equal ClientChronicleLevel, harness.send(:verification_audit_level_class)
    assert_equal ClientChronicleLevel::NOTHING, harness.send(:verification_default_activity_level_id)
    assert_equal ClientChronicle, harness.send(:verification_activity_model)
    assert_equal visitor, harness.send(:current_verification_actor)
    assert_equal "Visitor", harness.send(:verification_actor_type)
    assert_equal :visitor_token_id, harness.send(:verification_token_foreign_key)
    assert_equal :passkeys, harness.send(:verification_passkeys_scope)
    assert_equal VisitorPasskey, harness.send(:verification_passkey_model)
    assert harness.send(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.send(:verification_no_passkey_i18n_key)
    assert_equal %i(email_otp passkey), harness.send(:step_up_supported_methods)
    assert_includes harness.send(:verification_unavailable_redirect_path), "ri=tokyo"
    assert_includes harness.send(:verification_success_fallback_path), "ri=tokyo"
  end

  test "send_email_otp! fails without a verified visitor email and delivers otherwise" do
    harness = Harness.new
    emails = []
    visitor = Struct.new(:public_id, :visitor_emails).new("vis-1", Object.new)
    visitor.visitor_emails.define_singleton_method(:where) { |*| emails }
    emails.define_singleton_method(:order) { |*| emails }
    emails.define_singleton_method(:first) { nil }
    harness.visitor = visitor

    assert_equal false, harness.send(:send_email_otp!)
    assert_equal [I18n.t("sign.app.verification.errors.email_not_verified")], harness.instance_variable_get(:@verification_errors)

    record = Object.new
    emails.define_singleton_method(:first) { record }
    delivered = []
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**kwargs| delivered << kwargs }

    OtpAdapter.stub(:for, adapter) do
      assert harness.send(:send_email_otp!)
    end

    assert_equal "digest-123456", harness.otp_session["otp_digest"]
    assert_equal record, delivered.first[:record]
  end
end
