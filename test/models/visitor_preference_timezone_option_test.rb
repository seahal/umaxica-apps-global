# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_timezone_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_timezone_options_on_id  (id) UNIQUE
#
require "test_helper"

class VisitorPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  test "name returns Etc UTC for ETC_UTC id" do
    option = VisitorPreferenceTimezoneOption.find_or_create_by!(id: VisitorPreferenceTimezoneOption::ETC_UTC)

    assert_equal "Etc/UTC", option.name
  end

  test "name returns Asia Tokyo for ASIA_TOKYO id" do
    option = VisitorPreferenceTimezoneOption.find_or_create_by!(id: VisitorPreferenceTimezoneOption::ASIA_TOKYO)

    assert_equal "Asia/Tokyo", option.name
  end

  test "name returns United States timezones" do
    expectations = {
      VisitorPreferenceTimezoneOption::AMERICA_NEW_YORK => "America/New_York",
      VisitorPreferenceTimezoneOption::AMERICA_CHICAGO => "America/Chicago",
      VisitorPreferenceTimezoneOption::AMERICA_DENVER => "America/Denver",
      VisitorPreferenceTimezoneOption::AMERICA_LOS_ANGELES => "America/Los_Angeles",
      VisitorPreferenceTimezoneOption::AMERICA_ANCHORAGE => "America/Anchorage",
      VisitorPreferenceTimezoneOption::PACIFIC_HONOLULU => "Pacific/Honolulu",
    }

    expectations.each do |id, timezone|
      assert_equal timezone, VisitorPreferenceTimezoneOption.new(id: id).name
    end
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end
end
