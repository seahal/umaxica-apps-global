# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthIoKeysTest < ActiveSupport::TestCase
  test "io keys module is loadable" do
    assert defined?(Auth::IoKeys)
  end

  test "auth io key values stay stable" do
    assert_equal "__Host-", Auth::IoKeys::HOST_COOKIE_PREFIX
    assert_equal "auth_access", Auth::IoKeys::Cookies::ACCESS_BASENAME
    assert_equal "auth_refresh", Auth::IoKeys::Cookies::REFRESH_BASENAME
    assert_equal "Authorization", Auth::IoKeys::Headers::AUTHORIZATION
    assert_equal :pt, Auth::IoKeys::Params::PT
    assert_equal :nt, Auth::IoKeys::Params::NT
    assert_equal :user_email_authentication_pt, Auth::IoKeys::Session::DEFAULT_PT
  end
end
