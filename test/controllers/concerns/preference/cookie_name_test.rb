# typed: false
# frozen_string_literal: true

require "test_helper"

module Preference
  class CookieNameTest < ActiveSupport::TestCase
    test "returns non production cookie names without secure prefix" do
      assert_equal "preference_access", Preference::CookieName.access(production: false)
      assert_equal "preference_refresh", Preference::CookieName.refresh(production: false)
    end

    test "returns production cookie names with secure prefix" do
      assert_equal "__Secure-preference_access", Preference::CookieName.access(production: true)
      assert_equal "__Secure-preference_refresh", Preference::CookieName.refresh(production: true)
    end

    test "returns non production dbsc cookie name" do
      assert_equal "preference_dbsc", Preference::CookieName.dbsc(production: false)
    end

    test "returns production dbsc cookie name with secure prefix" do
      assert_equal "__Secure-preference_dbsc", Preference::CookieName.dbsc(production: true)
    end

    test "returns surface scoped credential cookie names" do
      assert_equal "app_preference_access", Preference::CookieName.access(production: false, surface: :app)
      assert_equal "com_preference_refresh", Preference::CookieName.refresh(production: false, surface: :com)
      assert_equal "org_preference_dbsc", Preference::CookieName.dbsc(production: false, surface: :org)
    end
  end
end
