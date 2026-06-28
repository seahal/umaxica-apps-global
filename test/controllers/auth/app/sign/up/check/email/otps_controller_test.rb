# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::Up::Check::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")
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

  test "show renders the otp form" do
    start_email_signup!("email-show@example.com")

    get auth_app_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
  end

  test "patch with a valid otp advances to the birthdate checkpoint" do
    user_email = start_email_signup!("email-valid@example.com")
    cycle = current_sign_up_cycle

    patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: otp_code_for(user_email) } },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp")
    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.reload.user_email_status_id
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.reload.step
    assert cycle.reload.completed_requirements.dig("otp", "cleared")
    assert_predicate cycle.reload.completed_requirements.dig("otp", "cleared_at"), :present?
  end

  test "show with an expired otp redirects to the start" do
    user_email = start_email_signup!("email-show-expired@example.com")

    travel_to(user_email.reload.otp_expires_at + 1.second) do
      get auth_app_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
  end

  test "patch with an expired otp redirects to the start" do
    user_email = start_email_signup!("email-expired@example.com")

    travel_to(user_email.reload.otp_expires_at + 1.second) do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
            params: { client_email: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
  end

  test "patch with a blank otp returns a validation error" do
    start_email_signup!("email-blank@example.com")

    patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "patch with an invalid otp returns a validation error" do
    start_email_signup!("email-wrong@example.com")

    patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: "000000" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    user_email = start_email_signup!("email-lock@example.com")
    cycle = current_sign_up_cycle
    completed_requirements = cycle.completed_requirements.deep_dup

    Email::MAX_OTP_ATTEMPTS.times do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
            params: { client_email: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_predicate user_email.reload, :locked?
    assert_equal "init", session[SignEmailRegistrable::SESSION_KEY]
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  private

  def start_email_signup!(email)
    post(
      auth_app_sign_up_email_url(ri: "jp"),
      params: {
        user_email: {
          raw_address: email,
          confirm_policy: "1",
        },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    ClientEmail.order(:created_at).last
  end

  def current_sign_up_cycle
    ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
  end

  def otp_code_for(user_email)
    otp_data = user_email.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end
