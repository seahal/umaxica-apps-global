# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthIoKeysTest < ActiveSupport::TestCase
  test "io keys modules are loadable" do
    assert defined?(Auth::IoKeys)
    assert defined?(Preference::IoKeys)
  end

  test "auth io key values stay stable" do
    assert_equal "__Host-", Auth::IoKeys::HOST_COOKIE_PREFIX
    assert_equal "auth_access", Auth::IoKeys::Cookies::ACCESS_BASENAME
    assert_equal "auth_refresh", Auth::IoKeys::Cookies::REFRESH_BASENAME
    assert_equal "auth_device_id", Auth::IoKeys::Cookies::DEVICE_BASENAME
    assert_equal "Authorization", Auth::IoKeys::Headers::AUTHORIZATION
    assert_equal "X-Device-Id", Auth::IoKeys::Headers::DEVICE_ID
    assert_equal :rt, Auth::IoKeys::Params::RT
    assert_equal :user_email_authentication_rt, Auth::IoKeys::Session::DEFAULT_RT
  end

  test "preference io key values stay stable" do
    assert_equal "__Secure-", Preference::IoKeys::SECURE_COOKIE_PREFIX
    assert_equal "ct", Preference::IoKeys::Cookies::THEME
    assert_equal "language", Preference::IoKeys::Cookies::LANGUAGE
    assert_equal "tz", Preference::IoKeys::Cookies::TIMEZONE
    assert_equal "preference_access", Preference::IoKeys::Cookies::ACCESS_BASENAME
    assert_equal "preference_refresh", Preference::IoKeys::Cookies::REFRESH_BASENAME
    assert_equal "preference_device_id", Preference::IoKeys::Cookies::DEVICE_BASENAME
    assert_equal "X-Device-Id", Preference::IoKeys::Headers::DEVICE_ID
    assert_equal :refresh_token, Preference::IoKeys::Params::REFRESH_TOKEN
  end
end
