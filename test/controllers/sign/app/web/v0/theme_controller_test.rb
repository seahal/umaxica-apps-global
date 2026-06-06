# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = PreferenceBase # ensure autoload of JwtConfiguration/Token defined in same file
    @host = JitIdHostEnv.service_url || "id.app.localhost"
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(PreferenceCookieName.access)

    get sign_app_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "dr" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[PreferenceCookieName.access(surface: :app)] = token

    with_preference_jwt_keys(host: @host) do
      get sign_app_web_v0_theme_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[PreferenceCookieName.access(surface: :app)] = token

    with_preference_jwt_keys(host: @host) do
      patch sign_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=dr"
  end
end
