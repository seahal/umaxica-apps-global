# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_timezone_options
# Database name: operator
#
#  id :bigint           not null, primary key
#
require "test_helper"

class StaffPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  fixtures :staff_preference_timezone_options

  test "returns Etc/UTC for ETC_UTC id" do
    option = staff_preference_timezone_options(:etc_utc)

    assert_equal "Etc/UTC", option.name
  end

  test "returns Asia/Tokyo for ASIA_TOKYO id" do
    option = staff_preference_timezone_options(:asia_tokyo)

    assert_equal "Asia/Tokyo", option.name
  end

  test "returns nil for unknown id" do
    option = StaffPreferenceTimezoneOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing default records" do
    StaffPreferenceTimezoneOption.where(id: StaffPreferenceTimezoneOption::DEFAULTS).destroy_all

    StaffPreferenceTimezoneOption.ensure_defaults!

    assert StaffPreferenceTimezoneOption.exists?(id: StaffPreferenceTimezoneOption::ETC_UTC)
    assert StaffPreferenceTimezoneOption.exists?(id: StaffPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    StaffPreferenceTimezoneOption.ensure_defaults!
    initial_count = StaffPreferenceTimezoneOption.count

    StaffPreferenceTimezoneOption.ensure_defaults!

    assert_equal initial_count, StaffPreferenceTimezoneOption.count
  end

  test "ensure_defaults! uses Prosopite.pause when defined" do
    StaffPreferenceTimezoneOption.where(id: StaffPreferenceTimezoneOption::DEFAULTS).destroy_all
    pause_called = false

    Prosopite.stub(
      :pause,
      ->(&block) {
        pause_called = true
        block.call
      },
    ) do
      StaffPreferenceTimezoneOption.ensure_defaults!
    end

    assert pause_called
    assert StaffPreferenceTimezoneOption.exists?(id: StaffPreferenceTimezoneOption::ETC_UTC)
    assert StaffPreferenceTimezoneOption.exists?(id: StaffPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "DEFAULTS constant exists" do
    assert_equal [1, 2], StaffPreferenceTimezoneOption::DEFAULTS
  end

  test "has_many staff_preference_timezones association" do
    option = staff_preference_timezone_options(:etc_utc)

    assert_respond_to option, :staff_preference_timezones
  end
end
