# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_binding_methods
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceBindingMethodTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, OrgPreferenceBindingMethod::NOTHING
    assert_equal 1, OrgPreferenceBindingMethod::DBSC
    assert_equal 2, OrgPreferenceBindingMethod::LEGACY
  end

  test "defaults includes NOTHING, DBSC, and LEGACY" do
    assert_includes OrgPreferenceBindingMethod::DEFAULTS, OrgPreferenceBindingMethod::NOTHING
    assert_includes OrgPreferenceBindingMethod::DEFAULTS, OrgPreferenceBindingMethod::DBSC
    assert_includes OrgPreferenceBindingMethod::DEFAULTS, OrgPreferenceBindingMethod::LEGACY
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "OrgPreferenceBindingMethod.count" do
      OrgPreferenceBindingMethod.ensure_defaults!
    end
  end
end
