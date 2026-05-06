# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = Preference::Base # ensure autoload of JwtConfiguration/Token defined in same file
    @host = IdHostEnv.staff_url || "id.org.localhost"
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(Preference::CookieName.access)

    get sign_org_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "li" },
      host: @host,
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get sign_org_web_v0_theme_path, as: :json
    end

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch sign_org_web_v0_theme_path, params: { theme: "light" }, as: :json
    end

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::IoKeys::Cookies::THEME}=li"
  end
end
