# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_density_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = ComPreferenceDensityOption.new(id: ComPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = ComPreferenceDensityOption.new(id: ComPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ComPreferenceDensityOption.new(id: ComPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end
end
