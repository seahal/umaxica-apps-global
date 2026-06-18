# typed: false
# frozen_string_literal: true

require "test_helper"

module Preference
  class CookieNameTest < ActiveSupport::TestCase
    test "returns non production cookie names without secure prefix" do
      assert_equal "preference_access", PreferenceCookieName.access(production: false)
      assert_equal "preference_refresh", PreferenceCookieName.refresh(production: false)
    end

    test "returns production cookie names with host prefix" do
      assert_equal "__Host-preference_access", PreferenceCookieName.access(production: true)
      assert_equal "__Host-preference_refresh", PreferenceCookieName.refresh(production: true)
    end

    test "returns non production dbsc cookie name" do
      assert_equal "preference_dbsc", PreferenceCookieName.dbsc(production: false)
    end

    test "returns production dbsc cookie name with host prefix" do
      assert_equal "__Host-preference_dbsc", PreferenceCookieName.dbsc(production: true)
    end

    test "ignores surface for new credential cookie names" do
      assert_equal "preference_access", PreferenceCookieName.access(production: false, surface: :app)
      assert_equal "preference_refresh", PreferenceCookieName.refresh(production: false, surface: :com)
      assert_equal "preference_dbsc", PreferenceCookieName.dbsc(production: false, surface: :org)
    end

    test "keeps legacy scoped names in compatibility read lists" do
      assert_includes PreferenceCookieName.legacy_access_names(production: false, surface: :app),
                      "app_preference_access"
      assert_includes PreferenceCookieName.legacy_refresh_names(production: false, surface: :com),
                      "com_preference_refresh"
      assert_includes PreferenceCookieName.legacy_dbsc_names(production: false, surface: :org), "org_preference_dbsc"
      assert_includes PreferenceCookieName.legacy_refresh_names(production: true, surface: :app),
                      "__Secure-app_preference_refresh"
    end
  end
end
