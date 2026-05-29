# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Acme::App::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(Preference::CookieName.access)

    get acme_app_web_v0_cookie_path, as: :json

    assert_response :ok
    body = response.parsed_body

    assert_not body["consented"]
    assert_not body["functional"]
    assert_not body["performant"]
    assert_not body["targetable"]
  end

  test "GET show returns consented false when jwt decode fails" do
    cookies[Preference::CookieName.access] = "invalid.jwt.token"

    with_preference_jwt_keys(host: @host) do
      get acme_app_web_v0_cookie_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_not response.parsed_body["consented"]
  end

  test "GET show returns consent state from jwt payload" do
    token = encode_preference_jwt(
      preferences: { "consented" => true, "functional" => true, "performant" => false, "targetable" => false },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get acme_app_web_v0_cookie_path, as: :json

      assert_response :success
    end

    assert_response :ok
    body = response.parsed_body

    assert body["consented"]
    assert body["functional"]
    assert_not body["performant"]
    assert_not body["targetable"]
  end

  test "PATCH update returns 200 and sets preference_consented cookie with app domain" do
    expires_at = Time.utc(2030, 1, 2, 3, 4, 5)

    travel_to(expires_at - Preference::Base::REFRESH_TOKEN_TTL) do
      token = encode_preference_jwt(
        preferences: { "consented" => true },
        host: @host,
        public_id: "pref-app-public-id",
      )
      cookies[Preference::CookieName.access] = token

      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".app.localhost") do
        with_preference_jwt_keys(host: @host) do
          patch acme_app_web_v0_cookie_path, as: :json
        end
      end
    end

    assert_response :ok
    assert response.parsed_body["consented"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_includes set_cookie, "domain=.app.localhost"
    assert_includes set_cookie.downcase, "path=/"
    expires = response_cookie_expiry("preference_consented")

    assert_not_nil expires
    assert_in_delta expires_at.to_i, expires.to_i, 1
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
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch acme_app_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.app_preference_cookie.consented
    assert_not_nil preference.app_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented="
    assert_includes set_cookie, "#{Preference::CookieName.access}="
  end

  test "PATCH update raises and rolls back consent when access token issue fails" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    cookie = AppPreferenceCookie.create!(
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
    cookies[Preference::CookieName.access] = token
    with_preference_jwt_keys(host: @host) do
      Preference::Token.stub(:encode, ->(*) { raise NoMethodError, "issue_access_token_from" }) do
        assert_raises(NoMethodError) do
          patch acme_app_web_v0_cookie_path, params: { consented: true }, as: :json
        end
      end
    end

    cookie.reload

    assert_not cookie.consented
    assert_nil cookie.consented_at
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
