# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthIoKeysTest < ActiveSupport::TestCase
  test "io keys module is loadable" do
    assert defined?(AuthIoKeys)
  end

  test "auth io key values stay stable" do
    assert_equal "__Host-", AuthIoKeys::HOST_COOKIE_PREFIX
    assert_equal "auth_access", AuthIoKeys::Cookies::ACCESS_BASENAME
    assert_equal "auth_refresh", AuthIoKeys::Cookies::REFRESH_BASENAME
    assert_equal "Authorization", AuthIoKeys::Headers::AUTHORIZATION
    assert_equal :pt, AuthIoKeys::Params::PT
    assert_equal :nt, AuthIoKeys::Params::NT
    assert_equal :user_email_authentication_pt, AuthIoKeys::Session::DEFAULT_PT
  end
end
