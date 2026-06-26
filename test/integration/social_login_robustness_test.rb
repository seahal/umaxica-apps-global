# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialLoginRobustnessTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_google_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
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
    get sign_app_social_google_callback_url(ri: "jp", state: "invalid_state"),
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
        sign_app_social_google_callback_url(ri: "jp"),
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
    clients(:one)

    # Set link intent without authentication
    seed_social_auth_session(provider: "google_app", intent: "link", ri: "jp")

    get sign_app_social_google_callback_url(ri: "jp"),
        params: { state: social_auth_state_from_response },
        headers: social_callback_headers(@host)

    assert_includes [301, 302, 401, 403], response.status,
                    "Link intent without authentication should return error/redirect, got #{response.status}"
  end

  test "social auth rejects step_up intent without satisfying step-up" do
    user = clients(:one)

    # Create a social identity for the user
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: "step_up_test_#{SecureRandom.hex(4)}",
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    # First, link the identity
    ClientGoogleIdentity.create!(
      user: user,
      uid: OmniAuth.config.mock_auth[:google_app].uid,
      provider: "google_app",
      token: "existing_token",
      refresh_token: "existing_refresh",
      token_expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    original_step_up_at = user.reload.last_step_up_at

    get sign_app_social_google_sign_in_url(intent: "step_up", ri: "jp"),
        headers: as_user_headers(user, host: @host)

    assert_response :redirect
    user.reload
    if original_step_up_at
      assert_equal original_step_up_at, user.last_step_up_at
    else
      assert_nil user.last_step_up_at
    end
  end

  test "social login callback with MFA account does not fail open" do
    # Even if the user has MFA enabled, the social login process itself shouldn't
    # require entering MFA code during the callback
    user = clients(:one)

    # Setup user with MFA
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )

    # Setup social identity
    ClientGoogleIdentity.create!(
      user: user,
      uid: "mfa_test_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "test_token",
      refresh_token: "test_refresh",
      token_expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Setup mock auth
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: user.client_google_identities.first.uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "new_token_#{SecureRandom.hex(8)}",
        refresh_token: "new_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    state = seed_social_auth_session(provider: "google_app", intent: "login", ri: "jp")

    # Do callback - this should redirect to MFA, but the callback processing itself
    # should not fail
    get sign_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_not_equal 500, response.status,
                     "Social login callback should not return 500 even if MFA is required"
    assert_includes [301, 302, 400, 403, 422], response.status
  end

  test "social auth request phase ignores oversized referer to avoid cookie overflow" do
    long_referer = "https://#{@host}/" + ("x" * 10_000)

    state = seed_social_auth_session(
      provider: "google_app",
      intent: "login",
      ri: "jp",
      referer: long_referer,
    )

    assert_predicate state, :present?
    assert_response :redirect
    assert_nil session["omniauth.origin"]
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence ||
      begin
        uri = URI.parse(response.location.to_s)
        Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
      rescue URI::InvalidURIError
        nil
      end
  end
end
