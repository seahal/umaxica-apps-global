# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Auth::App::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = JitIdHostEnv.service_url || "auth.app.localhost"
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(PreferenceCookieName.access)

    get auth_app_web_v0_cookie_path, as: :json

    assert_response :ok
    body = response.parsed_body

    assert_not body["consented"]
    assert_not body["functional"]
    assert_not body["performant"]
    assert_not body["targetable"]
  end

  test "GET show returns consent state from jwt payload" do
    token = encode_preference_jwt(
      preferences: { "consented" => true, "functional" => false, "performant" => false, "targetable" => false },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[PreferenceCookieName.access(surface: :app)] = token

    with_preference_jwt_keys(host: @host) do
      get auth_app_web_v0_cookie_path, as: :json

      assert_response :success
    end

    assert_response :ok
    body = response.parsed_body

    assert body["consented"]
    assert_not body["functional"]
    assert_not body["performant"]
    assert_not body["targetable"]
  end

  test "PATCH update with consented true updates preference cookie and issues access token" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    AppPreferenceCookie.create!(
      preference: preference,
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
      consented_at: nil,
    )
    token = encode_preference_jwt(
      preferences: { "consented" => false },
      host: @host,
      public_id: preference.public_id,
    )
    cookies[PreferenceCookieName.access(surface: :app)] = token

    with_preference_jwt_keys(host: @host) do
      patch auth_app_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.app_preference_cookie.consented
    assert_not_nil preference.app_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceCookieName.access}="
    assert_includes set_cookie, "preference_consented=1"
    assert_not_includes response_set_cookie_lines.find { |line|
      line.start_with?("preference_consented=")
    }.to_s.downcase,
                        "httponly"
  end

  test "PATCH update without access jwt writes consent buffer without credential cookies" do
    cookies.delete(PreferenceCookieName.access)

    assert_no_difference -> { AppPreference.count } do
      patch auth_app_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
    assert_not_includes set_cookie, "#{PreferenceCookieName.access}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end
end
