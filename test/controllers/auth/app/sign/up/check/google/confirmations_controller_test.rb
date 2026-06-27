# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::Up::Check::Google::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "show does not redirect signed-in clients away from the google confirmation checkpoint" do
    user = clients(:one)

    get sign_app_sign_up_check_google_confirmation_url(ri: "jp"),
        headers: as_user_headers(user, host: @host)

    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end

  test "update requires turnstile before clearing the social confirmation requirement" do
    controller = Auth::App::Sign::Up::Check::Google::ConfirmationsController.new
    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "PATCH",
      "HTTP_HOST" => @host,
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    ticket = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
      step: "social_callback",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(16)),
      issued_at: Time.current,
      expires_at: ClientSignUpFlow.default_ttl.from_now,
      entry_method: "google",
      social_provider: "google",
    )
    controller.instance_variable_set(:@sign_up_ticket, ticket)
    controller.define_singleton_method(:load_gate_context!) { |*| true }
    controller.define_singleton_method(:gate_for_update) { nil }
    controller.define_singleton_method(:params) do |*|
      ActionController::Parameters.new(confirm_new_social_identity: "1", "cf-turnstile-response": "bad")
    end
    controller.define_singleton_method(:render_turnstile_failure) do
      controller.response_body = I18n.t("turnstile_error")
      controller.status = :unprocessable_content
    end
    controller.define_singleton_method(:verify_social_signup_turnstile!) { false }

    controller.send(:update)

    assert_equal 422, controller.response.status
    assert_includes controller.response.body, I18n.t("turnstile_error")
  end
end
