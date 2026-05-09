# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_region_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class CustomerPreferenceRegionOptionTest < ActiveSupport::TestCase
  test "name returns US for US id" do
    option = CustomerPreferenceRegionOption.find_or_create_by!(id: CustomerPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = CustomerPreferenceRegionOption.find_or_create_by!(id: CustomerPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = CustomerPreferenceRegionOption.find_or_create_by!(id: CustomerPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
