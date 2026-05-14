# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_timezone_options
# Database name: setting
#
#  id :bigint           not null, primary key
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

  test "name returns nil for unknown id" do
    option = VisitorPreferenceTimezoneOption.new(id: 99)

    assert_nil option.name
  end
end
