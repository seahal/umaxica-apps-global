# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Telephone::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "patch with a valid otp advances to the guard checkpoint" do
    visitor_telephone = start_telephone_signup!("+1234567801")
    cycle = current_sign_up_cycle

    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.status_id

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: otp_code_for(visitor_telephone) } },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to auth_com_sign_up_guard_telephone_url(ri: "jp")
    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.step
    assert cycle.completed_requirements.dig("otp", "cleared")
    assert_equal 1, cycle.checkpoint_version
  end

  test "a verified telephone stays unverified until the finalizer promotes it" do
    visitor_telephone = start_telephone_signup!("+1234567802")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: otp_code_for(visitor_telephone) } },
          headers: default_headers

    assert_equal(
      VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      visitor_telephone.reload.visitor_telephone_status_id,
    )
    # The passkey and passcode steps read ownership from the session, so the
    # flag has to survive the OTP step for the checkpoint to stay reachable.
    assert session.dig(:visitor_telephone_registration, "otp_verified")
  end

  test "the guard forwards a verified ticket to the passkey step" do
    visitor_telephone = start_telephone_signup!("+1234567803")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: otp_code_for(visitor_telephone) } },
          headers: default_headers
    follow_redirect!

    assert_response :redirect
    assert_match auth_com_sign_up_check_telephone_passkey_path, response.location
  end

  test "patch with a blank otp returns a validation error" do
    start_telephone_signup!("+1234567804")

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.code_required")
  end

  test "patch with an invalid otp leaves the ticket at contact pending" do
    start_telephone_signup!("+1234567805")
    cycle = current_sign_up_cycle

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: "000000" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.invalid_code")
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
    assert_equal 0, cycle.checkpoint_version
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    visitor_telephone = start_telephone_signup!("+1234567806")
    cycle = current_sign_up_cycle

    Telephone::MAX_OTP_ATTEMPTS.times do
      patch auth_com_sign_up_check_telephone_otp_url(ri: "jp"),
            params: { visitor_telephone: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.attempts_exceeded")
    assert_predicate visitor_telephone.reload, :locked?
    assert_nil session[:visitor_telephone_registration]
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  private

  def start_telephone_signup!(number)
    post(
      auth_com_sign_up_telephone_url(ri: "jp"),
      params: {
        visitor_telephone: {
          raw_number: number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    VisitorTelephone.order(:created_at).last
  end

  def current_sign_up_cycle
    public_id = session.dig(:com_sign_up_flow_locator, "public_id")
    return if public_id.blank?

    VisitorSignUpFlow.find_by(public_id: public_id)
  end

  def otp_code_for(visitor_telephone)
    otp_data = visitor_telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def csrf_token_value
    "test-csrf-token"
  end
end
