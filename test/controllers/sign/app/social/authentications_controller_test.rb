# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "continue redirects to google oauth with valid provider" do
    post sign_app_social_google_connection_path(provider: "google_app", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
  end

  test "continue stores only social ceremony transaction id in cookie session" do
    post sign_app_social_google_connection_path(provider: "google_app", ri: "jp")

    assert_response :redirect

    stored_value = session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]

    assert_predicate stored_value, :present?
    assert_nil session[SocialAuth::SOCIAL_PT_SESSION_KEY]
    assert_no_match(/\./, stored_value, "session must not store the signed social ceremony grant JWT")
    assert_operator stored_value.bytesize, :<, 80
    assert ClientSocialCeremonyTransaction.find_by(transaction_id: stored_value)
  end

  test "continue without entry parameter does not raise and defaults to sign-in flow" do
    post sign_app_social_google_connection_path(provider: "google_app", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
  end

  test "continue redirects to apple oauth with valid provider" do
    post sign_app_social_apple_connection_path(provider: "apple", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/apple}, response.location
  end

  test "continue with sign up entry issues social sign up cycle" do
    post sign_app_social_google_connection_path(provider: "google_app", ri: "jp"),
         params: {
           entry: "sign_up",
           pt: "/after-social",
         }

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location

    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", cycle.entry_method
    assert_equal "google", cycle.social_provider
    assert_nil cycle.return_to
    assert_equal "social_callback", cycle.step
  end

  test "start path is not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/social/auth/google_app/start",
        method: :post,
      )
    end
  end
end
