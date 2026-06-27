# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthProviderBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "log.umaxica.app")
    host! @host
    https! unless @host.include?("localhost")
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "google callback rejects forged id_info sub when uid is absent" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      info: {},
      credentials: {
        token: "google-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        id_info: {
          sub: "forged-google-sub",
          iat: Time.current.to_i,
        },
      },
    )
    state = seed_social_auth_session(provider: "google", intent: "login", ri: "jp")

    assert_no_difference("ClientGoogleIdentity.count") do
      get sign_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: social_callback_headers(@host)
    end

    assert_response :redirect
    assert_nil ClientGoogleIdentity.find_by(uid: "forged-google-sub")
  end

  test "callback rejects auth provider that does not match the route provider" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "provider-mismatch-uid",
      info: {},
      credentials: {
        token: "apple-token",
        expires_at: 1.week.from_now.to_i,
      },
    )
    state = seed_social_auth_session(provider: "google", intent: "login", ri: "jp")

    assert_no_difference("ClientAppleIdentity.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        get sign_app_social_google_callback_url(ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_response :redirect
  end

  test "callback rejects stale provider assertion iat" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "stale-iat-google",
      info: {},
      credentials: {
        token: "google-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        id_info: {
          iat: 30.minutes.ago.to_i,
        },
      },
    )
    state = seed_social_auth_session(provider: "google", intent: "login", ri: "jp")

    assert_no_difference("ClientGoogleIdentity.count") do
      get sign_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: social_callback_headers(@host)
    end

    assert_response :redirect
  end

  test "apple callback accepts provider nonce owned by omniauth strategy" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "apple-strategy-owned-nonce",
      info: {},
      credentials: {
        token: "apple-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        raw_info: {
          iat: Time.current.to_i,
          nonce: "omniauth-apple-generated-nonce",
        },
      },
    )
    state = seed_social_auth_session(provider: "apple", intent: "login", ri: "jp")

    get sign_app_social_apple_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
    assert_match(%r{/sign/up/guard/apple}, response.location)
  end
end
