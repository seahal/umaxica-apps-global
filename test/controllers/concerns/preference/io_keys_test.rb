# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class PreferenceIoKeysTest < ActiveSupport::TestCase
  test "io keys module is loadable" do
    assert defined?(PreferenceIoKeys)
  end

  test "preference io key values stay stable" do
    assert_equal "__Host-", PreferenceIoKeys::HOST_COOKIE_PREFIX
    assert_equal "__Host-", PreferenceIoKeys::SECURE_COOKIE_PREFIX
    assert_equal "ct", PreferenceIoKeys::Cookies::THEME
    assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
    assert_equal "tz", PreferenceIoKeys::Cookies::TIMEZONE
    assert_equal "cu", PreferenceIoKeys::Cookies::CURRENCY
    assert_equal "df", PreferenceIoKeys::Cookies::DATE_FORMAT
    assert_equal "tf", PreferenceIoKeys::Cookies::TIME_FORMAT
    assert_equal "mo", PreferenceIoKeys::Cookies::MOTION
    assert_equal "dn", PreferenceIoKeys::Cookies::DENSITY
    assert_equal "ps", PreferenceIoKeys::Cookies::PAGE_SIZE
    assert_equal "preference_access", PreferenceIoKeys::Cookies::ACCESS_BASENAME
    assert_equal "preference_refresh", PreferenceIoKeys::Cookies::REFRESH_BASENAME
  end

  test "preference refresh token is never accepted via URL or body params" do
    # Refresh tokens flow only through HttpOnly cookies. Reintroducing a
    # params constant would invite logging and Referer leaks.
    assert_not PreferenceIoKeys::Params.const_defined?(:REFRESH_TOKEN, false)
  end
end
