# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::App::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = PreferenceBase # ensure autoload of JwtConfiguration/Token defined in same file
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(PreferenceCookieName.access)

    get base_app_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "dr" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get base_app_web_v0_theme_path, as: :json

      assert_response :success
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "GET show returns theme from cookie when present" do
    cookies[PreferenceIoKeys::Cookies::THEME] = "li"

    get base_app_web_v0_theme_path, as: :json

    assert_response :ok
    assert_equal "li", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-app-public-id",
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=dr"
  end

  test "PATCH update with preference record updates theme and issues access token" do
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: PreferenceBase::REFRESH_TOKEN_TTL.from_now,
    )
    option_class = PreferenceClassRegistry.option_class("App", :theme)
    ensure_theme_defaults!(option_class)
    AppPreferenceTheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: preference.public_id,
    )
    cookies[PreferenceCookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch base_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    preference.reload

    assert_equal option_class::DARK, preference.app_preference_theme.option_id
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=dr"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::CURRENCY}=jpy"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::DATE_FORMAT}=iso"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::TIME_FORMAT}=24"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::MOTION}=standard"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::DENSITY}=standard"
    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::PAGE_SIZE}=infinity"
    assert_includes set_cookie, "#{PreferenceCookieName.access(surface: :app)}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end

  test "PATCH update with refresh token fallback updates preference record" do
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      expires_at: PreferenceBase::REFRESH_TOKEN_TTL.from_now,
    )
    option_class = PreferenceClassRegistry.option_class("App", :theme)
    ensure_theme_defaults!(option_class)
    AppPreferenceTheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    refresh_token, verifier = AppPreference.generate_refresh_token(public_id: preference.public_id)
    preference.update!(token_digest: AppPreference.digest_refresh_token(verifier))
    cookies[PreferenceCookieName.refresh(surface: :app)] = refresh_token

    with_preference_jwt_keys(host: @host) do
      patch base_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    preference.reload

    assert_equal option_class::DARK, preference.app_preference_theme.option_id
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{PreferenceIoKeys::Cookies::THEME}=dr"
    assert_includes set_cookie, "#{PreferenceCookieName.access(surface: :app)}="
  end

  test "PATCH update does not issue auth access cookie with preference access token" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    option_class = PreferenceClassRegistry.option_class("App", :theme)
    ensure_theme_defaults!(option_class)
    AppPreferenceTheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: preference.public_id,
    )
    cookies[PreferenceCookieName.access(surface: :app)] = token

    with_preference_jwt_keys(host: @host) do
      patch base_app_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok

    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  private

  def ensure_theme_defaults!(option_class)
    option_class.ensure_defaults! if option_class.respond_to?(:ensure_defaults!)
  end
end
