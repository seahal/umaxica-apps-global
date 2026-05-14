# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_timezone_options
# Database name: principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  fixtures :user_preference_timezone_options

  test "returns Etc/UTC for ETC_UTC id" do
    option = user_preference_timezone_options(:etc_utc)

    assert_equal "Etc/UTC", option.name
  end

  test "returns Asia/Tokyo for ASIA_TOKYO id" do
    option = user_preference_timezone_options(:asia_tokyo)

    assert_equal "Asia/Tokyo", option.name
  end

  test "returns nil for unknown id" do
    option = UserPreferenceTimezoneOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing default records" do
    Prosopite.pause do
      UserPreferenceTimezoneOption.where(id: UserPreferenceTimezoneOption::DEFAULTS).destroy_all
    end

    UserPreferenceTimezoneOption.ensure_defaults!

    assert UserPreferenceTimezoneOption.exists?(id: UserPreferenceTimezoneOption::ETC_UTC)
    assert UserPreferenceTimezoneOption.exists?(id: UserPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    UserPreferenceTimezoneOption.ensure_defaults!
    initial_count = UserPreferenceTimezoneOption.count

    UserPreferenceTimezoneOption.ensure_defaults!

    assert_equal initial_count, UserPreferenceTimezoneOption.count
  end

  test "DEFAULTS constant exists" do
    assert_equal [1, 2], UserPreferenceTimezoneOption::DEFAULTS
  end

  test "has_many user_preference_timezones association" do
    option = user_preference_timezone_options(:etc_utc)

    assert_respond_to option, :user_preference_timezones
  end
end
