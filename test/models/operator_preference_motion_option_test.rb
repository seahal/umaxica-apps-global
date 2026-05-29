# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_motion_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = OperatorPreferenceMotionOption.new(id: OperatorPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = OperatorPreferenceMotionOption.new(id: OperatorPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceMotionOption.new(id: OperatorPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
