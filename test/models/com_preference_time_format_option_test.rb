# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_time_format_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceTimeFormatOptionTest < ActiveSupport::TestCase
  test "name returns hour_24 for HOUR_24 id" do
    option = ComPreferenceTimeFormatOption.new(id: ComPreferenceTimeFormatOption::HOUR_24)

    assert_equal "hour_24", option.name
  end

  test "name returns hour_12 for HOUR_12 id" do
    option = ComPreferenceTimeFormatOption.new(id: ComPreferenceTimeFormatOption::HOUR_12)

    assert_equal "hour_12", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ComPreferenceTimeFormatOption.new(id: ComPreferenceTimeFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceTimeFormatOption.new(id: 999)

    assert_nil option.name
  end
end
