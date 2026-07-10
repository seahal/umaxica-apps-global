# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_density_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = VisitorPreferenceDensityOption.new(id: VisitorPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = VisitorPreferenceDensityOption.new(id: VisitorPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceDensityOption.new(id: VisitorPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end
end
