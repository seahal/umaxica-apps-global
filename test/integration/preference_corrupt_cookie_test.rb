# typed: false
# frozen_string_literal: true

require "test_helper"

# A garbage/corrupt preference refresh cookie or access JWT must never raise
# an unhandled exception and must never be treated as authority over existing
# DB state. The current, intentional fail-closed behavior for a *presented but
# invalid* refresh token is a controlled 401 (not a silent bootstrap and not a
# 500) with the stale cookie cleared, so a replayed/garbage token cannot be
# used to smuggle state into an unrelated preference record.
class PreferenceCorruptCookieTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  REFRESH_COOKIE_NAME = -> { PreferenceCookieName.refresh(production: false, surface: :app) }
  ACCESS_COOKIE_NAME = -> { PreferenceCookieName.access(production: false, surface: :app) }

  test "garbage refresh cookie fails closed without raising and clears the stale cookie" do
    cookies[REFRESH_COOKIE_NAME.call] = "not-a-real-token.garbage"

    get "/preference?ri=jp"

    assert_response :unauthorized
    assert_predicate cookies[REFRESH_COOKIE_NAME.call].to_s, :empty?
  end

  test "garbage refresh cookie does not overwrite an existing preference's DB state" do
    get "/preference?ri=jp"

    assert_response :success

    existing = AppPreference.order(:created_at).last
    existing_region_option_id = existing.app_preference_region.option_id

    reset!
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    cookies[REFRESH_COOKIE_NAME.call] = "totally-invalid-cookie-value"

    get "/preference?ri=us"

    assert_response :unauthorized

    existing.reload

    assert_equal existing_region_option_id, existing.app_preference_region.option_id,
                 "a corrupt cookie from a different session must not mutate an unrelated existing preference"
  end

  test "absent refresh cookie (never presented) still bootstraps a fresh preference" do
    get "/preference?ri=jp"

    assert_response :success
    assert_not_nil cookies[REFRESH_COOKIE_NAME.call]
  end

  test "garbage access token JWT does not raise and falls back to refresh-token handling" do
    cookies[ACCESS_COOKIE_NAME.call] = "garbage.jwt.value"

    get "/preference?ri=jp"

    assert_response :success
  end
end
