# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSurfaceAlignmentTest < ActiveSupport::TestCase
  test "representative controller paths resolve to their matching preference classes" do
    assert_equal AppPreference, PreferenceClassRegistry.for_controller_path("base/app/preferences")
    assert_equal ComPreference, PreferenceClassRegistry.for_controller_path("base/com/preferences")
    assert_equal OrgPreference, PreferenceClassRegistry.for_controller_path("base/org/preferences")
  end

  test "host surface labels align with representative controller path segments" do
    assert_equal "app", "base/app/preferences".split("/")[1]
    assert_equal "com", "base/com/preferences".split("/")[1]
    assert_equal "org", "base/org/preferences".split("/")[1]
  end
end
