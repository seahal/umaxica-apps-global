# typed: false
# == Schema Information
#
# Table name: com_preference_timezone_options
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class ComPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "ensure_defaults! creates default timezone options" do
    ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS).delete_all

    assert_empty ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS)

    ComPreferenceTimezoneOption.ensure_defaults!

    assert_equal ComPreferenceTimezoneOption::DEFAULTS.sort, ComPreferenceTimezoneOption.where(id: ComPreferenceTimezoneOption::DEFAULTS).pluck(:id).sort
  end

  test "can be created" do
    option = ComPreferenceTimezoneOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many com_preference_timezones" do
    option = ComPreferenceTimezoneOption.create!(id: 99)
    preference = ComPreference.create!
    timezone = ComPreferenceTimezone.create!(preference: preference, option: option)

    assert_includes option.com_preference_timezones, timezone
  end

  test "restricts deletion when associated records exist" do
    option = ComPreferenceTimezoneOption.create!(id: 99)
    preference = ComPreference.create!
    ComPreferenceTimezone.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end
end
