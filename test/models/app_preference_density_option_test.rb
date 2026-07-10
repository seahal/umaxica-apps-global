# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_density_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = AppPreferenceDensityOption.new(id: AppPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = AppPreferenceDensityOption.new(id: AppPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceDensityOption.new(id: AppPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates default records" do
    AppPreferenceDensityOption.ensure_defaults!

    AppPreferenceDensityOption::DEFAULTS.each do |id|
      assert AppPreferenceDensityOption.exists?(id), "missing default app preference density option #{id}"
    end
  end
end
