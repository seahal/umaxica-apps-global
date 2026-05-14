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

  test "start remains a compatibility alias for valid provider" do
    post start_sign_app_social_authentication_path(provider: "google_app", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
  end

  test "continue redirects to sign-in with alert for unsupported provider" do
    post continue_sign_app_social_authentication_path(provider: "twitter", ri: "jp")

    assert_redirected_to new_sign_app_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.social.sessions.invalid_provider"), flash[:alert]
  end
end
