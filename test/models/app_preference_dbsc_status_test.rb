# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_dbsc_statuses
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceDbscStatusTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, AppPreferenceDbscStatus::NOTHING
    assert_equal 1, AppPreferenceDbscStatus::ACTIVE
    assert_equal 2, AppPreferenceDbscStatus::PENDING
    assert_equal 3, AppPreferenceDbscStatus::FAILED
    assert_equal 4, AppPreferenceDbscStatus::REVOKE
  end

  test "defaults includes all status values" do
    assert_includes AppPreferenceDbscStatus::DEFAULTS, AppPreferenceDbscStatus::NOTHING
    assert_includes AppPreferenceDbscStatus::DEFAULTS, AppPreferenceDbscStatus::ACTIVE
    assert_includes AppPreferenceDbscStatus::DEFAULTS, AppPreferenceDbscStatus::PENDING
    assert_includes AppPreferenceDbscStatus::DEFAULTS, AppPreferenceDbscStatus::FAILED
    assert_includes AppPreferenceDbscStatus::DEFAULTS, AppPreferenceDbscStatus::REVOKE
  end

  test "can load nothing status from db" do
    status = AppPreferenceDbscStatus.find(AppPreferenceDbscStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "AppPreferenceDbscStatus.count" do
      AppPreferenceDbscStatus.ensure_defaults!
    end
  end
end
