# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "continue redirects to google oauth with valid provider" do
    post continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
  end

  test "continue without entry parameter does not raise and defaults to sign-in flow" do
    post continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
  end

  test "continue redirects to apple oauth with valid provider" do
    post continue_sign_app_social_authentication_path(provider: "apple", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/apple}, response.location
  end

  test "continue with sign up entry issues social sign up cycle" do
    post continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp"),
         params: {
           entry: "sign_up",
           pt: "/after-social",
         }

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location

    cycle = ClientSignUpCycle.order(:id).last

    assert_equal "google", cycle.entry_method
    assert_equal "google", cycle.social_provider
    assert_equal "/after-social", cycle.return_to
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

  test "continue redirects to sign-in with alert for unsupported provider" do
    post continue_sign_app_social_authentication_path(provider: "twitter", ri: "jp")

    assert_redirected_to new_sign_app_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.social.sessions.invalid_provider"), flash[:alert]
  end
end
