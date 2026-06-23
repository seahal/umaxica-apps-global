# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_time_format_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceTimeFormatOptionTest < ActiveSupport::TestCase
  test "name returns 24 for HOUR_24 id" do
    option = AppPreferenceTimeFormatOption.new(id: AppPreferenceTimeFormatOption::HOUR_24)

    assert_equal "24", option.name
  end

  test "name returns 12 for HOUR_12 id" do
    option = AppPreferenceTimeFormatOption.new(id: AppPreferenceTimeFormatOption::HOUR_12)

    assert_equal "12", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceTimeFormatOption.new(id: AppPreferenceTimeFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceTimeFormatOption.new(id: 999)

    assert_nil option.name
  end
end
