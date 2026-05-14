# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_region_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceRegionOptionTest < ActiveSupport::TestCase
  test "name returns US for US id" do
    option = VisitorPreferenceRegionOption.find_or_create_by!(id: VisitorPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = VisitorPreferenceRegionOption.find_or_create_by!(id: VisitorPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceRegionOption.find_or_create_by!(id: VisitorPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
