# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceChronicleLevelTest < ActiveSupport::TestCase
  fixtures :com_preference_chronicle_levels

  test "includes all default ids" do
    ids = ComPreferenceChronicleLevel.pluck(:id)

    assert_empty(ComPreferenceChronicleLevel::DEFAULTS - ids)
  end

  test "has_many association with com_preference_chronicles" do
    association = ComPreferenceChronicleLevel.reflect_on_association(:com_preference_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
  end

  test "INFO constant is defined" do
    assert_equal 1, ComPreferenceChronicleLevel::INFO
  end

  test "record_timestamps is disabled" do
    assert_not ComPreferenceChronicleLevel.record_timestamps
  end

  test "DEFAULTS includes INFO" do
    assert_includes ComPreferenceChronicleLevel::DEFAULTS, ComPreferenceChronicleLevel::INFO
  end

  test "ensure_defaults! creates the INFO record" do
    ComPreferenceChronicle.delete_all
    ComPreferenceChronicleLevel.where(id: ComPreferenceChronicleLevel::INFO).delete_all

    assert_nil ComPreferenceChronicleLevel.find_by(id: ComPreferenceChronicleLevel::INFO)

    ComPreferenceChronicleLevel.ensure_defaults!

    assert_not_nil ComPreferenceChronicleLevel.find_by(id: ComPreferenceChronicleLevel::INFO)
  end

  test "ensure_defaults! is idempotent" do
    ComPreferenceChronicleLevel.ensure_defaults!
    assert_nothing_raised { ComPreferenceChronicleLevel.ensure_defaults! }
  end
end
