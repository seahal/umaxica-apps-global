# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::Up::Check::Telephone::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
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
    start_telephone_signup!("+1234567890")

    get sign_app_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.registration.telephone.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.registration.telephone.edit.code_label")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.registration.telephone.edit.submit")
  end

  test "show redirects expired otp sessions to the start" do
    user_telephone = start_telephone_signup!("+12345678905")

    travel_to(user_telephone.reload.otp_expires_at + 1.second) do
      get sign_app_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers
    end

    assert_response :redirect
    assert_redirected_to new_sign_app_sign_up_telephone_url(ri: "jp")
  end

  test "patch with a valid otp advances to the guard checkpoint" do
    user_telephone = start_telephone_signup!("+1234567891")
    cycle = current_sign_up_cycle

    patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { client_telephone: { pass_code: otp_code_for(user_telephone) } },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to sign_app_sign_up_guard_telephone_url(ri: "jp")
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, user_telephone.reload.user_telephone_status_id
    assert session.dig(:user_telephone_registration, "otp_verified")
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.reload.step
    assert cycle.reload.completed_requirements.dig("otp", "cleared")
  end

  test "patch with an expired otp redirects to the start" do
    user_telephone = start_telephone_signup!("+1234567896")

    travel_to(user_telephone.reload.otp_expires_at + 1.second) do
      patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"),
            params: { client_telephone: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :redirect
    assert_redirected_to new_sign_app_sign_up_telephone_url(ri: "jp")
  end

  test "patch with a blank otp returns a validation error" do
    start_telephone_signup!("+1234567892")

    patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { client_telephone: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.code_required")
  end

  test "patch with an invalid otp returns a validation error" do
    start_telephone_signup!("+1234567893")

    patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"),
          params: { client_telephone: { pass_code: "000000" } },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.invalid_code")
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    user_telephone = start_telephone_signup!("+1234567894")
    cycle = current_sign_up_cycle
    completed_requirements = cycle.completed_requirements.deep_dup

    Telephone::MAX_OTP_ATTEMPTS.times do
      patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"),
            params: { client_telephone: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.telephone.update.attempts_exceeded")
    assert_predicate user_telephone.reload, :locked?
    assert_nil session[:user_telephone_registration]
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  private

  def start_telephone_signup!(telephone)
    post(
      sign_app_sign_up_telephone_url(ri: "jp"),
      params: {
        client_telephone: {
          raw_number: telephone,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )

    assert_response :redirect
    ClientTelephone.order(:created_at).last
  end

  def current_sign_up_cycle
    ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
  end

  def otp_code_for(user_telephone)
    otp_data = user_telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def default_headers
    { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end
