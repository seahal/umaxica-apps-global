# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_region_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceRegionOptionTest < ActiveSupport::TestCase
  test "name returns US for US id" do
    option = OperatorPreferenceRegionOption.find_or_create_by!(id: OperatorPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = OperatorPreferenceRegionOption.find_or_create_by!(id: OperatorPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceRegionOption.find_or_create_by!(id: OperatorPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
