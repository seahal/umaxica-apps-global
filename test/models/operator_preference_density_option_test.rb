# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_density_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = OperatorPreferenceDensityOption.new(id: OperatorPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = OperatorPreferenceDensityOption.new(id: OperatorPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceDensityOption.new(id: OperatorPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end
end
