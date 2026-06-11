# typed: false
# frozen_string_literal: true

require "test_helper"
require "sha3"

# Regression tests for security-sensitive paths around
# www.umaxica.{app,com,org}/preference (the acme preference authority).
#
# These tests pin the security invariants surfaced during the May 2026
# review: preference refresh tokens must stay in HttpOnly cookies, timezone
# updates must reject non-IANA strings, and pt= redirect parameters must
# never be allowed to escape the current host.
class PreferenceSecurityTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("ACME_SERVICE_URL", "www.umaxica.app")
  end

  COOKIE_NAME = -> { PreferenceCookieName.refresh(production: false, surface: :app) }

  test "refresh_token URL parameter cannot replace the HttpOnly cookie" do
    # Bootstrap a preference + cookie pair.
    get edit_acme_app_preference_region_url(ri: "jp")

    assert_response :success
    legitimate_token = cookies[COOKIE_NAME.call]

    assert_not_nil legitimate_token

    # Switch session and try to ride a stolen refresh token through ?refresh_token=.
    reset!
    https!
    host! ENV.fetch("ACME_SERVICE_URL", "www.umaxica.app")
    get edit_acme_app_preference_region_url(ri: "jp", refresh_token: legitimate_token)

    assert_response :success

    new_token = cookies[COOKIE_NAME.call]

    assert_not_nil new_token
    assert_not_equal legitimate_token, new_token,
                     "URL params must not adopt the presented refresh token"
  end

  test "timezone update rejects unknown raw strings even with a slash" do
    get edit_acme_app_preference_timezone_url(ri: "jp")

    assert_response :success

    patch acme_app_preference_timezone_url(ri: "jp"),
          params: { preference_timezone: { option_id: "../etc/passwd" } }

    # The fix routes invalid input through PreferenceOperationError and
    # redirects back with a localized alert, never writing to session/cookie.
    assert_redirected_to edit_acme_app_preference_timezone_url(ri: "jp")
    assert_equal I18n.t("errors.messages.preference_operation_failed"), flash[:alert]

    follow_redirect!

    timezone_cookie = cookies[PreferenceBase::TIMEZONE_COOKIE_KEY]

    assert_not_equal "../etc/passwd", timezone_cookie
  end

  test "theme update pt redirect refuses absolute URLs and protocol-relative paths" do
    get edit_acme_app_preference_theme_url(ri: "jp")

    assert_response :success

    [
      "https://evil.example/pwn",
      "//evil.example/pwn",
      "/\\evil.example/pwn",
    ].each do |hostile_pt|
      patch acme_app_preference_theme_url(ri: "jp", pt: hostile_pt),
            params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect,
                      "theme update should still redirect for pt=#{hostile_pt.inspect}"
      location = response.headers["Location"].to_s

      assert_no_match(
        /evil\.example/, location,
        "theme update must not redirect to external host (pt=#{hostile_pt.inspect})",
      )
    end
  end

  test "internal pt path is preserved when safe" do
    get edit_acme_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch acme_app_preference_theme_url(ri: "jp", pt: "/preference?ri=jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect
    assert_includes response.headers["Location"], "/preference"
  end
end
