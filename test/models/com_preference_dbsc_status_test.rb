# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_dbsc_statuses
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceDbscStatusTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, ComPreferenceDbscStatus::NOTHING
    assert_equal 1, ComPreferenceDbscStatus::ACTIVE
    assert_equal 2, ComPreferenceDbscStatus::PENDING
    assert_equal 3, ComPreferenceDbscStatus::FAILED
    assert_equal 4, ComPreferenceDbscStatus::REVOKE
  end

  test "defaults includes all status values" do
    assert_includes ComPreferenceDbscStatus::DEFAULTS, ComPreferenceDbscStatus::NOTHING
    assert_includes ComPreferenceDbscStatus::DEFAULTS, ComPreferenceDbscStatus::ACTIVE
    assert_includes ComPreferenceDbscStatus::DEFAULTS, ComPreferenceDbscStatus::PENDING
    assert_includes ComPreferenceDbscStatus::DEFAULTS, ComPreferenceDbscStatus::FAILED
    assert_includes ComPreferenceDbscStatus::DEFAULTS, ComPreferenceDbscStatus::REVOKE
  end

  test "can load nothing status from db" do
    status = ComPreferenceDbscStatus.find(ComPreferenceDbscStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "ComPreferenceDbscStatus.count" do
      ComPreferenceDbscStatus.ensure_defaults!
    end
  end
end
