# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Apex::Com::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(Preference::CookieName.access)

    get apex_com_web_v0_cookie_path, as: :json

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
      get apex_com_web_v0_cookie_path, as: :json

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
      get apex_com_web_v0_cookie_path, as: :json
    end

    assert_response :ok
    assert_not response.parsed_body["consented"]
    assert_not response.parsed_body["functional"]
    assert_not response.parsed_body["performant"]
    assert_not response.parsed_body["targetable"]
  end

  test "PATCH update returns 200 and sets preference_consented cookie with com domain" do
    token = encode_preference_jwt(
      preferences: { "consented" => false },
      host: @host,
      public_id: "pref-com-public-id",
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token
    expires_at = Time.utc(2031, 2, 3, 4, 5, 6)

    travel_to(expires_at - Preference::Base::REFRESH_TOKEN_TTL) do
      with_cookie_domain_credentials(COOKIE_DOMAIN_COM: ".com.localhost") do
        with_preference_jwt_keys(host: @host) do
          patch apex_com_web_v0_cookie_path, as: :json
        end
      end
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=0"
    assert_includes set_cookie, "domain=.com.localhost"
    assert_includes set_cookie.downcase, "path=/"
    expires = response_cookie_expiry("preference_consented")

    assert_not_nil expires
    assert_in_delta expires_at.to_i, expires.to_i, 1
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
      patch apex_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.com_preference_cookie.consented
    assert_not_nil preference.com_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented="
    assert_includes set_cookie, "#{Preference::CookieName.access}="
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
