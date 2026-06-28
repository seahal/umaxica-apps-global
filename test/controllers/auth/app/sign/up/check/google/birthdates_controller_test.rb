# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::Up::Check::Google::BirthdatesControllerTest < ActionDispatch::IntegrationTest
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

  test "update does not redirect signed-in clients away from the google birthdate checkpoint" do
    user = clients(:one)

    patch auth_app_sign_up_check_google_birthdate_url(ri: "jp"),
          headers: as_user_headers(user, host: @host)

    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end

  test "underage birthdate renders an age-restricted recovery page and terminalizes the flow" do
    travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
      sign_up_state = start_google_social_signup!
      flow = ClientSignUpFlow.order(:created_at).last

      assert_predicate sign_up_state, :present?

      patch auth_app_sign_up_check_google_confirmation_url(ri: "jp"),
            params: {
              :confirm_new_social_identity => "1",
              :checkpoint_version => flow.checkpoint_version,
              "cf-turnstile-response" => "test",
            },
            headers: social_callback_headers(@host)

      assert_redirected_to auth_app_sign_up_check_google_birthdate_url(ri: "jp")

      patch auth_app_sign_up_check_google_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              checkpoint_version: flow.reload.checkpoint_version,
              birthdate: "2010-06-26",
            },
            headers: social_callback_headers(@host)

      assert_response :success
      assert_includes response.body, "16歳"
      assert_select "form[action='#{auth_app_sign_up_path(ri: "jp")}'][method=get]"
      assert_equal ClientSignUpFlowStatus::FAILED, flow.reload.status_id

      get auth_app_sign_up_check_google_birthdate_url(ri: "jp"), headers: social_callback_headers(@host)

      assert_response :success
      assert_includes response.body, "16歳"
      assert_select "form[action='#{auth_app_sign_up_path(ri: "jp")}'][method=get]"
    end
  end

  private

  def start_google_social_signup!
    setup_google_mock_auth(uid: "google-underage-#{SecureRandom.hex(4)}")

    get(auth_app_social_google_auth_up_url(provider: "google", ri: "jp"))

    assert_response :redirect
    state = social_auth_state_from_response

    assert_predicate state, :present?

    get(
      auth_app_social_google_callback_url(provider: "google", ri: "jp"),
      params: { state: state },
      headers: social_callback_headers(@host),
    )

    assert_redirected_to auth_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to auth_app_sign_up_check_google_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_select "input[name=confirm_new_social_identity][required]"

    state
  end
end
