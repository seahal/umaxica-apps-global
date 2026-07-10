# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_motion_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = AppPreferenceMotionOption.new(id: AppPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = AppPreferenceMotionOption.new(id: AppPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceMotionOption.new(id: AppPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
