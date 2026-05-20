# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_dbsc_statuses
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceDbscStatusTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, OrgPreferenceDbscStatus::NOTHING
    assert_equal 1, OrgPreferenceDbscStatus::ACTIVE
    assert_equal 2, OrgPreferenceDbscStatus::PENDING
    assert_equal 3, OrgPreferenceDbscStatus::FAILED
    assert_equal 4, OrgPreferenceDbscStatus::REVOKE
    assert_equal [0, 1, 2, 3, 4], OrgPreferenceDbscStatus::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      OrgPreferenceDbscStatus.where(id: OrgPreferenceDbscStatus::DEFAULTS).destroy_all
    end

    OrgPreferenceDbscStatus.ensure_defaults!

    assert OrgPreferenceDbscStatus.exists?(id: OrgPreferenceDbscStatus::NOTHING)
    assert OrgPreferenceDbscStatus.exists?(id: OrgPreferenceDbscStatus::ACTIVE)
    assert OrgPreferenceDbscStatus.exists?(id: OrgPreferenceDbscStatus::PENDING)
  end

  test "has_many org_preferences association" do
    status = OrgPreferenceDbscStatus.new(id: 1)

    assert_respond_to status, :org_preferences
  end
end
