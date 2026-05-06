# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::ComVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  CustomerStruct = Struct.new(:id, :public_id, :customer_emails, :customer_passkeys)

  class Harness
    include Sign::ComVerificationBase::Overrides

    ALLOWED_SCOPES = Sign::AppVerificationBase::ALLOWED_SCOPES
    REAUTH_SESSION_KEY = Sign::AppVerificationBase::REAUTH_SESSION_KEY
    EMAIL_OTP_SESSION_KEY = Sign::AppVerificationBase::EMAIL_OTP_SESSION_KEY
    REAUTH_TTL = Sign::AppVerificationBase::REAUTH_TTL

    attr_accessor :customer, :params_hash, :session_hash, :redirect_args, :restore_result, :generated_hotp

    def initialize(customer:)
      @customer = customer
      @params_hash = {}
      @session_hash = {}
      @restore_result = false
      @generated_hotp = ["secret", 1, "123456"]
    end

    def current_customer = customer

    def session = session_hash

    def params = params_hash.with_indifferent_access

    def safe_internal_path(path)
      (path.to_s.start_with?("/") && !path.to_s.start_with?("//")) ? path : nil
    end

    def current_reauth_session
      session[REAUTH_SESSION_KEY]
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
  end

  test "start_reauth_session stores a valid customer session" do
    customer = CustomerStruct.new(42, "cust-public-id", [], [])
    harness = Harness.new(customer: customer)
    return_to = Base64.urlsafe_encode64("/configuration/emails/new")

    travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
      harness.send(:start_reauth_session!, scope: "configuration_email", return_to_param: return_to)

      session = harness.session_hash[Harness::REAUTH_SESSION_KEY]

      assert_equal 42, session["customer_id"]
      assert_equal "configuration_email", session["scope"]
      assert_equal "/configuration/emails/new", session["return_to"]
      assert_equal 15.minutes.from_now.to_i, session["expires_at"]
    end
  end

  test "start_reauth_session rejects invalid return path and scope mismatch" do
    customer = CustomerStruct.new(42, "cust-public-id", [], [])
    harness = Harness.new(customer: customer)

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
    customer = CustomerStruct.new(42, "cust-public-id", [], [])
    harness = Harness.new(customer: customer)

    valid_session = {
      "customer_id" => 42,
      "scope" => "configuration_email",
      "return_to" => "/configuration/emails",
      "expires_at" => 5.minutes.from_now.to_i,
    }

    assert harness.send(:valid_reauth_session?, valid_session)
    assert_not harness.send(:valid_reauth_session?, valid_session.merge("expires_at" => 1.minute.ago.to_i))
    assert_not harness.send(:valid_reauth_session?, valid_session.merge("customer_id" => 7))
    assert_not harness.send(:valid_reauth_session?, valid_session.merge("scope" => ""))
    assert_not harness.send(:valid_reauth_session?, valid_session.merge("return_to" => ""))
  end

  test "handle_invalid_reauth_session clears session and redirects when restore fails" do
    customer = CustomerStruct.new(42, "cust-public-id", [], [])
    harness = Harness.new(customer: customer)
    harness.params_hash = { ri: "jp" }
    harness.session_hash[Harness::REAUTH_SESSION_KEY] = { "customer_id" => 42 }
    harness.session_hash[Harness::EMAIL_OTP_SESSION_KEY] = { "secret" => "old" }

    assert_not harness.send(:handle_invalid_reauth_session!)
    assert_nil harness.session_hash[Harness::REAUTH_SESSION_KEY]
    assert_nil harness.session_hash[Harness::EMAIL_OTP_SESSION_KEY]
    assert_match "/verification?", harness.redirect_args.first.first
  end

  test "com verification exposes customer specific models and values" do
    customer = CustomerStruct.new(42, "cust-public-id", [], [])
    passkey = Struct.new(:customer_id).new(42)
    harness = Harness.new(customer: customer)
    harness.params_hash = { ri: "jp" }

    assert_equal 42, harness.send(:reauth_actor_id)
    assert_equal "/verification?ri=jp", harness.send(:verification_unavailable_redirect_path)
    assert_equal CustomerVerification, harness.send(:verification_model)
    assert_equal UserChronicleEvent::STEP_UP_VERIFIED, harness.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.send(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.send(:verification_success_fallback_path)
    assert_equal UserChronicleEvent, harness.send(:verification_audit_event_class)
    assert_equal UserChronicleLevel, harness.send(:verification_audit_level_class)
    assert_equal UserChronicleLevel::NOTHING, harness.send(:verification_default_activity_level_id)
    assert_equal UserChronicle, harness.send(:verification_activity_model)
    assert_equal customer, harness.send(:current_verification_actor)
    assert_equal "Customer", harness.send(:verification_actor_type)
    assert_equal :customer_token_id, harness.send(:verification_token_foreign_key)
    assert_equal [], harness.send(:verification_passkeys_scope)
    assert_equal CustomerPasskey, harness.send(:verification_passkey_model)
    assert harness.send(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.send(:verification_no_passkey_i18n_key)
    assert_equal [], harness.send(:active_totp_credentials)
    assert_equal %i(email_otp passkey), harness.send(:step_up_supported_methods)
  end

  test "send_email_otp records session data and handles missing verified email" do
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)

    customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
    harness = Harness.new(customer: customer)

    assert_not harness.send(:send_email_otp!)
    assert_equal ["メールアドレスが未確認です"], harness.instance_variable_get(:@verification_errors)

    CustomerEmail.create!(
      customer: customer,
      address: "com-verification-otp@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )
    harness.session_hash[Harness::REAUTH_SESSION_KEY] = { "expires_at" => 5.minutes.from_now.to_i }

    assert harness.send(:send_email_otp!)
    assert_equal(
      { "secret" => "secret",
        "counter" => 1,
        "expires_at" => harness.session_hash[Harness::REAUTH_SESSION_KEY]["expires_at"], },
      harness.session_hash[Harness::EMAIL_OTP_SESSION_KEY],
    )
  end
end
