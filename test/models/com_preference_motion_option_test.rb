# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_motion_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = ComPreferenceMotionOption.new(id: ComPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = ComPreferenceMotionOption.new(id: ComPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ComPreferenceMotionOption.new(id: ComPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
