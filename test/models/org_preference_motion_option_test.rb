# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_motion_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = OrgPreferenceMotionOption.new(id: OrgPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = OrgPreferenceMotionOption.new(id: OrgPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OrgPreferenceMotionOption.new(id: OrgPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
