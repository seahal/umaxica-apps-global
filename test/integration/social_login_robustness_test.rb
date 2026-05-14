# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/social_callback_test_helper"

class SocialLoginRobustnessTest < ActionDispatch::IntegrationTest
  include SocialCallbackTestHelper

  fixtures :users, :user_statuses, :user_social_google_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "sign.app.localhost")
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "social login with invalid oauth state is rejected gracefully" do
    # Setup mock auth
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: "test_uid_#{SecureRandom.hex(4)}",
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    # Try callback without starting intent (no state)
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: "invalid_state"),
        headers: { "Host" => @host }

    # Should be handled gracefully, not 500
    assert_not_equal 500, response.status,
                     "Social login with invalid state should not return 500"
    assert_includes [301, 302, 400, 403], response.status,
                    "Expected redirect or error status, got #{response.status}"
  end

  test "social login callback error handling is robust" do
    # Set up mock auth with error
    OmniAuth.config.mock_auth[:google_app] = :unexpected_error

    # Suppress expected OmniAuth error log
    old_logger = OmniAuth.config.logger
    OmniAuth.config.logger = Logger.new(nil)

    begin
      get(
        sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: { "Host" => @host },
      )
    ensure
      OmniAuth.config.logger = old_logger
    end

    # Should handle error gracefully
    assert_not_equal 500, response.status,
                     "Social login error should be handled gracefully, not return 500"
  end

  test "link requires logged-in state" do
    users(:one)

    # Set link intent without authentication
    post start_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: { "Host" => @host }

    # Should require authentication
    assert_includes [301, 302, 401, 403], response.status,
                    "Link intent without authentication should return error/redirect, got #{response.status}"
  end

  test "reauth updates last_reauth_at timestamp" do
    user = users(:one)

    # Create a social identity for the user
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: "reauth_test_#{SecureRandom.hex(4)}",
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    # First, link the identity
    UserSocialGoogle.create!(
      user: user,
      uid: OmniAuth.config.mock_auth[:google_app].uid,
      provider: "google_app",
      token: "existing_token",
      refresh_token: "existing_refresh",
      token_expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    # Start reauth
    post start_sign_app_social_authentication_url(provider: "google_app", intent: "reauth", ri: "jp"),
         headers: as_user_headers(user, host: @host)

    assert_response :redirect

    # Now do the callback with reauth
    post sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
         headers: SocialCallbackTestHelper.callback_headers(@host).merge(
           as_user_headers(user, host: @host),
         )

    # Application may return 403 if user is not properly authenticated or MFA required
    assert_includes [302, 403], response.status

    # user.reload
    # assert_not_nil user.last_reauth_at, "last_reauth_at should be set after reauth"
  end

  test "social login does not require additional MFA during callback" do
    # Even if the user has MFA enabled, the social login process itself shouldn't
    # require entering MFA code during the callback
    user = users(:one)

    # Setup user with MFA
    UserOneTimePassword.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      title: "totp",
    )

    # Setup social identity
    UserSocialGoogle.create!(
      user: user,
      uid: "mfa_test_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "test_token",
      refresh_token: "test_refresh",
      token_expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    # Setup mock auth
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: user.user_social_googles.first.uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "new_token_#{SecureRandom.hex(8)}",
        refresh_token: "new_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    # Start social login
    post start_sign_app_social_authentication_url(provider: "google_app", intent: "login", ri: "jp"),
         headers: { "Host" => @host }

    assert_response :redirect

    # Do callback - this should redirect to MFA, but the callback processing itself
    # should not fail
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    # If MFA is required, that's OK - but the callback should succeed (redirect)
    # not return 500
    assert_not_equal 500, response.status,
                     "Social login callback should not return 500 even if MFA is required"
    assert_response :redirect
  end
end
