# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_region_options
# Database name: operator
#
#  id :bigint           not null, primary key
#
require "test_helper"

class StaffPreferenceRegionOptionTest < ActiveSupport::TestCase
  test "name returns US for US id" do
    option = StaffPreferenceRegionOption.find_or_create_by!(id: StaffPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = StaffPreferenceRegionOption.find_or_create_by!(id: StaffPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = StaffPreferenceRegionOption.find_or_create_by!(id: StaffPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
