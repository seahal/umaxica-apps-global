# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_motion_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = VisitorPreferenceMotionOption.new(id: VisitorPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = VisitorPreferenceMotionOption.new(id: VisitorPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceMotionOption.new(id: VisitorPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
