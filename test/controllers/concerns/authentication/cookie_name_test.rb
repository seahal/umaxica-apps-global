# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authentication
  class CookieNameTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "returns non production cookie names without secure prefix" do
      assert_equal "auth_access", AuthenticationCookieName.access(production: false)
      assert_equal "auth_refresh", AuthenticationCookieName.refresh(production: false)
    end

    test "returns production cookie names with host prefix" do
      assert_equal "__Host-auth_access", AuthenticationCookieName.access(production: true)
      assert_equal "__Host-auth_refresh", AuthenticationCookieName.refresh(production: true)
    end

    test "returns non production dbsc cookie name" do
      assert_equal "auth_dbsc", AuthenticationCookieName.dbsc(production: false)
    end

    test "returns production dbsc cookie name with host prefix" do
      assert_equal "__Host-auth_dbsc", AuthenticationCookieName.dbsc(production: true)
    end
  end
end
