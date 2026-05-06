# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = Preference::Base # ensure autoload of JwtConfiguration/Token defined in same file
    @host = ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(Preference::CookieName.access)

    get apex_app_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "dr" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get apex_app_web_v0_theme_path, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "GET show returns theme from cookie when present" do
    cookies[Preference::IoKeys::Cookies::THEME] = "li"

    get apex_app_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch apex_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::IoKeys::Cookies::THEME}=dr"
  end

  test "PATCH update with ct param sets theme cookie" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch apex_app_web_v0_theme_path, params: { ct: "li" }, as: :json
    end

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
  end

  test "PATCH update with preference record updates colortheme and issues access token" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    option_class = Preference::ClassRegistry.option_class("App", :colortheme)
    ensure_colortheme_defaults!(option_class)
    AppPreferenceColortheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: preference.public_id,
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch apex_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    preference.reload

    assert_equal option_class::DARK, preference.app_preference_colortheme.option_id
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::IoKeys::Cookies::THEME}=dr"
    assert_includes set_cookie, "#{Preference::CookieName.access}="
  end

  private

  def ensure_colortheme_defaults!(option_class)
    option_class.ensure_defaults! if option_class.respond_to?(:ensure_defaults!)
  end
end
