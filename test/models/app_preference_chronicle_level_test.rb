# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceChronicleLevelTest < ActiveSupport::TestCase
  fixtures :app_preference_chronicle_levels

  test "includes all default ids" do
    ids = AppPreferenceChronicleLevel.pluck(:id)

    assert_empty(AppPreferenceChronicleLevel::DEFAULTS - ids)
  end

  test "INFO constant is defined" do
    assert_equal 1, AppPreferenceChronicleLevel::INFO
  end

  test "record_timestamps is disabled" do
    assert_not AppPreferenceChronicleLevel.record_timestamps
  end

  test "has_many association with app_preference_chronicles" do
    association = AppPreferenceChronicleLevel.reflect_on_association(:app_preference_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
  end

  test "DEFAULTS includes INFO" do
    assert_includes AppPreferenceChronicleLevel::DEFAULTS, AppPreferenceChronicleLevel::INFO
  end

  test "ensure_defaults! creates the INFO record" do
    AppPreferenceChronicle.delete_all
    AppPreferenceChronicleLevel.where(id: AppPreferenceChronicleLevel::INFO).delete_all

    assert_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)

    AppPreferenceChronicleLevel.ensure_defaults!

    assert_not_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)
  end

  test "ensure_defaults! is idempotent" do
    AppPreferenceChronicleLevel.ensure_defaults!
    assert_nothing_raised { AppPreferenceChronicleLevel.ensure_defaults! }
  end
end
