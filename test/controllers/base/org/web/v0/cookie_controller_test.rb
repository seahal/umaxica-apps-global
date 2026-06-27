# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Base::Org::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(PreferenceCookieName.access)

    get base_org_web_v0_cookie_path, as: :json

    assert_response :ok
    assert_not response.parsed_body["consented"]
  end

  test "GET show returns consent state from jwt payload" do
    token = encode_preference_jwt(
      preferences: { "consented" => true, "functional" => true, "performant" => true, "targetable" => false },
      host: @host,
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get base_org_web_v0_cookie_path, as: :json

      assert_response :success
    end

    assert_response :ok
    body = response.parsed_body

    assert body["consented"]
    assert body["functional"]
    assert body["performant"]
    assert_not body["targetable"]
  end

  test "PATCH update without preference jwt writes consent buffer without credential cookies" do
    cookies.delete(PreferenceCookieName.access(surface: :org))

    assert_no_difference -> { OrgPreference.count } do
      patch base_org_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    assert response.parsed_body["consented"]
    set_cookie = response.headers["Set-Cookie"].to_s
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
    assert_not_includes set_cookie, "#{PreferenceCookieName.access(surface: :org)}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end

  test "PATCH update with consented true updates org preference cookie and issues access token" do
    preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
    OrgPreferenceCookie.create!(
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
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_org_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.org_preference_cookie.consented
    assert_not_nil preference.org_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceCookieName.access}="
    assert_includes set_cookie, "preference_consented=1"
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
  end

  test "PATCH update with nested accept-all cookie params updates every consent flag" do
    preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
    OrgPreferenceCookie.create!(
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
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_org_web_v0_cookie_path,
            params: {
              cookie: {
                consented: true,
                functional: true,
                performant: true,
                targetable: true,
              },
            },
            as: :json
    end

    assert_response :ok
    cookie = preference.reload.org_preference_cookie

    assert cookie.consented
    assert cookie.functional
    assert cookie.performant
    assert cookie.targetable
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
