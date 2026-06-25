# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::Up::Check::Email::BirthdatesControllerTest < ActionDispatch::IntegrationTest
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

  # Regression: email sign-up hands off to the sign-in checkpoint on Sign.
  test "clearing the birthdate completes the sign-up on sign" do
    advance_to_birthdate_checkpoint!("birthdate-finalize@example.com")
    flow = ClientSignUpFlow.order(:created_at).last

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to sign_app_sign_in_check_path(ri: "jp")

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.reload.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to sign_app_sign_in_check_path(ri: "jp")
  end

  test "update without a sign-up ticket does not raise an unsafe cross-host redirect" do
    user = clients(:one)

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          headers: as_user_headers(user, host: @host)

    # No sign-in flow present for this signed-in client, so the gate failure renders the
    # plain "ticket is required" body instead of attempting a handoff redirect. The key
    # assertion is that it never raises ActionController::Redirecting::OpenRedirectError.
    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end

  test "rejects app client signup one day before the sixteenth birthday with sixteen birthday copy" do
    travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
      advance_to_birthdate_checkpoint!("birthdate-under16@example.com")
      flow = ClientSignUpFlow.order(:created_at).last

      patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              checkpoint_version: flow.checkpoint_version,
              birthdate: "2010-06-26",
            },
            headers: { "Host" => @host }

      assert_response :success
      assert_includes response.body, "16歳の誕生日"
      assert_not_includes response.body, "13歳の誕生日"
      assert_equal ClientSignUpFlowStatus::FAILED, flow.reload.status_id
      assert_not flow.requirement_cleared?(:birthdate)
    end
  end

  test "allows app client signup on the sixteenth birthday" do
    travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
      advance_to_birthdate_checkpoint!("birthdate-sixteen@example.com")
      flow = ClientSignUpFlow.order(:created_at).last

      patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              checkpoint_version: flow.checkpoint_version,
              birthdate: "2010-06-25",
            },
            headers: { "Host" => @host }

      assert_response :redirect
      assert_redirected_to sign_app_sign_in_check_path(ri: "jp")
      assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
    end
  end

  test "allows app client signup after the sixteenth birthday" do
    travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
      advance_to_birthdate_checkpoint!("birthdate-over16@example.com")
      flow = ClientSignUpFlow.order(:created_at).last

      patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              checkpoint_version: flow.checkpoint_version,
              birthdate: "2000-01-01",
            },
            headers: { "Host" => @host }

      assert_response :redirect
      assert_redirected_to sign_app_sign_in_check_path(ri: "jp")
      assert_equal ClientSignUpFlowStatus::COMPLETED, flow.reload.status_id
    end
  end

  private

  def advance_to_birthdate_checkpoint!(email)
    user_email = start_pending_email_flow!(email)
    pass_code = otp_code_for(user_email)

    patch(
      sign_app_sign_up_check_email_otp_url(ri: "jp"),
      params: { client_email: { pass_code: pass_code } },
      headers: { "Host" => @host },
    )

    assert_response :redirect
    user_email
  end

  def start_pending_email_flow!(email)
    post(
      sign_app_sign_up_email_url(ri: "jp"),
      params: {
        :user_email => {
          raw_address: email,
          confirm_policy: "1",
        },
        "cf-turnstile-response" => "test",
      },
      headers: { "Host" => @host },
    )

    assert_response :redirect
    ClientEmail.order(:created_at).last
  end

  def otp_code_for(user_email)
    otp_data = user_email.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end
end
