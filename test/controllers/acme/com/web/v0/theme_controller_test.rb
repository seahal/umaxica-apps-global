# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Acme::Com::Web::V0::ThemeControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    _ = Preference::Base # ensure autoload of JwtConfiguration/Token defined in same file
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "GET show without access jwt returns default theme sy" do
    cookies.delete(Preference::CookieName.access)

    get acme_com_web_v0_theme_path, as: :json

    assert_response :success
    assert_equal "sy", response.parsed_body["theme"]
  end

  test "GET show returns theme from preference jwt" do
    token = encode_preference_jwt(
      preferences: { "ct" => "li" },
      host: @host,
      public_id: "pref-com-public-id",
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      get acme_com_web_v0_theme_path, as: :json

      assert_response :success
    end

    assert_response :success
    assert_equal "li", response.parsed_body["theme"]
  end

  test "PATCH update sets theme cookie and returns updated theme" do
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: "pref-com-public-id",
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch acme_com_web_v0_theme_path, params: { theme: "dark" }, as: :json
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body["theme"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::IoKeys::Cookies::THEME}=dr"
  end

  test "PATCH update with preference record updates theme and issues access token" do
    preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
    option_class = Preference::ClassRegistry.option_class("Com", :theme)
    ensure_theme_defaults!(option_class)
    ComPreferenceTheme.create!(
      preference: preference,
      option_id: option_class::SYSTEM,
    )
    token = encode_preference_jwt(
      preferences: { "ct" => "sy" },
      host: @host,
      public_id: preference.public_id,
      preference_type: "ComPreference",
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch acme_com_web_v0_theme_path, params: { theme: "light" }, as: :json
    end

    assert_response :ok
    preference.reload

    assert_equal option_class::LIGHT, preference.com_preference_theme.option_id
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "#{Preference::IoKeys::Cookies::THEME}=li"
    assert_includes set_cookie, "#{Preference::CookieName.access}="
  end

  private

  def ensure_theme_defaults!(option_class)
    option_class.ensure_defaults! if option_class.respond_to?(:ensure_defaults!)
  end
end
