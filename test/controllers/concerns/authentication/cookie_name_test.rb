# typed: false
# frozen_string_literal: true

require "test_helper"

module Authentication
  class CookieNameTest < ActiveSupport::TestCase
    fixtures_none!

    test "returns non production cookie names without secure prefix" do
      assert_equal "auth_access", Authentication::CookieName.access(production: false)
      assert_equal "auth_refresh", Authentication::CookieName.refresh(production: false)
      assert_equal "auth_device_id", Authentication::CookieName.device(production: false)
    end

    test "returns production cookie names with host prefix" do
      assert_equal "__Host-auth_access", Authentication::CookieName.access(production: true)
      assert_equal "__Host-auth_refresh", Authentication::CookieName.refresh(production: true)
      assert_equal "__Host-auth_device_id", Authentication::CookieName.device(production: true)
    end

    test "derives device cookie key from refresh cookie key" do
      refresh = "__Host-auth_refresh"

      assert_equal "__Host-auth_device_id", Authentication::CookieName.device(refresh_cookie_key: refresh)
    end

    test "returns non production dbsc cookie name" do
      assert_equal "auth_dbsc", Authentication::CookieName.dbsc(production: false)
    end

    test "returns production dbsc cookie name with host prefix" do
      assert_equal "__Host-auth_dbsc", Authentication::CookieName.dbsc(production: true)
    end
  end
end
