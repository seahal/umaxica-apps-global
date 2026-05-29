# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_density_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = OrgPreferenceDensityOption.new(id: OrgPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = OrgPreferenceDensityOption.new(id: OrgPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OrgPreferenceDensityOption.new(id: OrgPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end
end
