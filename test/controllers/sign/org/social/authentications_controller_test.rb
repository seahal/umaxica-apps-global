# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_visibilities

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "continue redirects to google oauth with valid provider" do
    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "true") do
      post continue_sign_org_social_authentication_path(provider: "google_org", ri: "jp")
    end

    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
  end

  test "continue redirects to sign-in when org google signin flag is off" do
    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "false") do
      post continue_sign_org_social_authentication_path(provider: "google_org", ri: "jp")
    end

    assert_redirected_to new_sign_org_sign_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.create.failure"), flash[:alert]
    assert_nil session[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  test "start path is not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/social/auth/google_org/start",
        method: :post,
      )
    end
  end

  test "continue redirects to sign-in with alert for unsupported provider (apple)" do
    post continue_sign_org_social_authentication_path(provider: "apple", ri: "jp")

    assert_redirected_to new_sign_org_sign_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end

  test "continue redirects to sign-in with alert for unknown provider" do
    post continue_sign_org_social_authentication_path(provider: "twitter", ri: "jp")

    assert_redirected_to new_sign_org_sign_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end

  test "signup redirects to sign-up when org google signup flag is off" do
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "false") do
      post signup_sign_org_social_authentication_path(provider: "google_org", ri: "jp")
    end

    assert_redirected_to new_sign_org_sign_up_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.create.failure"), flash[:alert]
    assert_nil session[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  test "signup redirects to google oauth when signup flag is on even if signin flag is off" do
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "true", "ORG_GOOGLE_SIGNIN_ENABLED" => "false") do
      post signup_sign_org_social_authentication_path(provider: "google_org", ri: "jp")
    end

    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
    assert_equal "sign_up", session[SocialAuthConcern::SOCIAL_ENTRY_SESSION_KEY]
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
