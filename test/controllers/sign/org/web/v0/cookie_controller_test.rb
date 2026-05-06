# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = IdHostEnv.staff_url || "id.org.localhost"
    host! @host
  end

  test "GET show without access jwt returns consented false" do
    cookies.delete(Preference::CookieName.access)

    get sign_org_web_v0_cookie_path, as: :json

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
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get sign_org_web_v0_cookie_path, as: :json
    end

    assert_response :ok
    body = response.parsed_body

    assert body["consented"]
    assert_not body["functional"]
    assert_not body["performant"]
    assert_not body["targetable"]
  end

  test "PATCH update with consented true updates preference cookie and issues access token" do
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
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch sign_org_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    preference.reload

    assert preference.org_preference_cookie.consented
    assert_not_nil preference.org_preference_cookie.consented_at
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented="
    assert_includes set_cookie, "#{Preference::CookieName.access}="
  end
end
