# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceIoKeysTest < ActiveSupport::TestCase
  test "io keys module is loadable" do
    assert defined?(Preference::IoKeys)
  end

  test "preference io key values stay stable" do
    assert_equal "__Secure-", Preference::IoKeys::SECURE_COOKIE_PREFIX
    assert_equal "ct", Preference::IoKeys::Cookies::THEME
    assert_equal "language", Preference::IoKeys::Cookies::LANGUAGE
    assert_equal "tz", Preference::IoKeys::Cookies::TIMEZONE
    assert_equal "cu", Preference::IoKeys::Cookies::CURRENCY
    assert_equal "df", Preference::IoKeys::Cookies::DATE_FORMAT
    assert_equal "tf", Preference::IoKeys::Cookies::TIME_FORMAT
    assert_equal "mo", Preference::IoKeys::Cookies::MOTION
    assert_equal "dn", Preference::IoKeys::Cookies::DENSITY
    assert_equal "ps", Preference::IoKeys::Cookies::PAGE_SIZE
    assert_equal "r18s", Preference::IoKeys::Cookies::ADULT_CONTENT_GATE
    assert_equal "preference_access", Preference::IoKeys::Cookies::ACCESS_BASENAME
    assert_equal "preference_refresh", Preference::IoKeys::Cookies::REFRESH_BASENAME
  end

  test "preference refresh token is never accepted via URL or body params" do
    # Refresh tokens flow only through HttpOnly cookies. Reintroducing a
    # params constant would invite logging and Referer leaks.
    assert_not Preference::IoKeys::Params.const_defined?(:REFRESH_TOKEN, false)
  end
end
