# typed: false
# frozen_string_literal: true

require "test_helper"

module Preference
  class ClassRegistryTest < ActiveSupport::TestCase
    test "resolves preference class from controller path" do
      assert_equal AppPreference, Preference::ClassRegistry.for_controller_path("core/app/edge/v0/preferences")
      assert_equal ComPreference, Preference::ClassRegistry.for_controller_path("core/com/edge/v0/preferences")
      assert_equal OrgPreference, Preference::ClassRegistry.for_controller_path("core/org/edge/v0/preferences")
    end

    test "resolves option classes by prefix and type" do
      assert_equal AppPreferenceLanguageOption, Preference::ClassRegistry.option_class("App", :language)
      assert_equal ComPreferenceRegionOption, Preference::ClassRegistry.option_class("Com", "Region")
      assert_equal OrgPreferenceTimezoneOption, Preference::ClassRegistry.option_class("Org", :timezone)
      assert_equal CustomerPreferenceThemeOption, Preference::ClassRegistry.option_class("Customer", :theme)
    end

    test "resolves status and audit classes from preference class" do
      assert_equal AppPreferenceStatus, Preference::ClassRegistry.status_class_for(AppPreference)
      assert_equal ComPreferenceChronicle, Preference::ClassRegistry.audit_class_for(ComPreference)
      assert_equal OrgPreferenceChronicleEvent, Preference::ClassRegistry.audit_event_class_for(OrgPreference)
    end
  end
end
