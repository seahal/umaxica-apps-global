# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceChronicleLevelTest < ActiveSupport::TestCase
  fixtures :org_preference_chronicle_levels

  test "includes all default ids" do
    ids = OrgPreferenceChronicleLevel.pluck(:id)

    assert_empty(OrgPreferenceChronicleLevel::DEFAULTS - ids)
  end

  test "has_many association with org_preference_chronicles" do
    association = OrgPreferenceChronicleLevel.reflect_on_association(:org_preference_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
  end

  test "INFO constant is defined" do
    assert_equal 1, OrgPreferenceChronicleLevel::INFO
  end

  test "record_timestamps is disabled" do
    assert_not OrgPreferenceChronicleLevel.record_timestamps
  end

  test "DEFAULTS includes INFO" do
    assert_includes OrgPreferenceChronicleLevel::DEFAULTS, OrgPreferenceChronicleLevel::INFO
  end

  test "ensure_defaults! creates the INFO record" do
    OrgPreferenceChronicle.delete_all
    OrgPreferenceChronicleLevel.where(id: OrgPreferenceChronicleLevel::INFO).delete_all

    assert_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)

    OrgPreferenceChronicleLevel.ensure_defaults!

    assert_not_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)
  end

  test "ensure_defaults! is idempotent" do
    OrgPreferenceChronicleLevel.ensure_defaults!
    assert_nothing_raised { OrgPreferenceChronicleLevel.ensure_defaults! }
  end
end
