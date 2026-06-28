# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = PreferenceBase # ensure autoload of JwtConfiguration/Token defined in same file
    @host = ENV.fetch("BASE_STAFF_URL")
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(PreferenceCookieName.access)

    get base_org_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "dr" },
      host: @host,
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get base_org_web_v0_theme_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-org-public-id",
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_org_web_v0_theme_path, params: { theme: "light" }, as: :json
    end

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=li"
  end

  test "PATCH update with preference record updates theme and issues access token" do
    preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
    option_class = PreferenceClassRegistry.option_class("Org", :theme)
    ensure_theme_defaults!(option_class)
    OrgPreferenceTheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: preference.public_id,
      preference_type: "OrgPreference",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_org_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    preference.reload

    assert_equal option_class::DARK, preference.org_preference_theme.option_id
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=dr"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::CURRENCY}=jpy"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::DATE_FORMAT}=iso"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::TIME_FORMAT}=24"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::MOTION}=standard"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::DENSITY}=standard"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::PAGE_SIZE}=infinity"
    assert_includes set_cookie, "#{PreferenceCookieName.access}="
  end

  private

  def ensure_theme_defaults!(option_class)
    option_class.ensure_defaults! if option_class.respond_to?(:ensure_defaults!)
  end
end
