# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Acme::Com::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(Preference::CookieName.access)

    get acme_com_web_v0_cookie_path, as: :json

    assert_response :ok
    assert_not response.parsed_body["consented"]
  end

  test "GET show returns consent state from jwt payload" do
    token = encode_preference_jwt(
      preferences: { "consented" => false, "functional" => false, "performant" => false, "targetable" => false },
      host: @host,
      public_id: "pref-com-public-id",
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get acme_com_web_v0_cookie_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_not response.parsed_body["consented"]
  end

  test "GET show ignores legacy access cookie for another preference surface" do
    token = encode_preference_jwt(
      preferences: { "consented" => true, "functional" => true, "performant" => true, "targetable" => true },
      host: @host,
      public_id: "pref-app-public-id",
      preference_type: "AppPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get acme_com_web_v0_cookie_path, as: :json
    end

    assert_response :ok
    assert_not response.parsed_body["consented"]
    assert_not response.parsed_body["functional"]
    assert_not response.parsed_body["performant"]
    assert_not response.parsed_body["targetable"]
  end

  test "PATCH update without preference jwt writes consent buffer without credential cookies" do
    cookies.delete(Preference::CookieName.access(surface: :com))

    assert_no_difference -> { ComPreference.count } do
      patch acme_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    assert response.parsed_body["consented"]
    set_cookie = response.headers["Set-Cookie"].to_s
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
    assert_not_includes set_cookie, "#{Preference::CookieName.access(surface: :com)}="
    assert_not_includes set_cookie, "#{Authentication::Base::ACCESS_COOKIE_KEY}="
  end

  test "PATCH update with consented true updates com preference cookie and issues access token" do
    preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
    ComPreferenceCookie.create!(
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
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch acme_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.com_preference_cookie.consented
    assert_not_nil preference.com_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::CookieName.access}="
    assert_includes set_cookie, "preference_consented=1"
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
  end

  test "PATCH update with nested reject-all cookie params records consent choice and clears optional flags" do
    preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
    ComPreferenceCookie.create!(
      preference: preference,
      targetable: true,
      performant: true,
      functional: true,
      consented: true,
      consented_at: Time.current,
    )
    token = encode_preference_jwt(
      preferences: { "consented" => true },
      host: @host,
      public_id: preference.public_id,
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch acme_com_web_v0_cookie_path,
            params: {
              cookie: {
                consented: true,
                functional: false,
                performant: false,
                targetable: false,
              },
            },
            as: :json
    end

    assert_response :ok
    cookie = preference.reload.com_preference_cookie

    assert cookie.consented
    assert_not cookie.functional
    assert_not cookie.performant
    assert_not cookie.targetable
    assert_not_nil cookie.consented_at
  end

  private

  def with_cookie_domain_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end
end
