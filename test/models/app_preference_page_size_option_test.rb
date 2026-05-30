# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_page_size_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferencePageSizeOptionTest < ActiveSupport::TestCase
  test "name returns 10 for PER_10 id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::PER_10)

    assert_equal "10", option.name
  end

  test "name returns 20 for PER_20 id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::PER_20)

    assert_equal "20", option.name
  end

  test "name returns 50 for PER_50 id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::PER_50)

    assert_equal "50", option.name
  end

  test "name returns 100 for PER_100 id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::PER_100)

    assert_equal "100", option.name
  end

  test "name returns infinity for PER_INFINITY id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::PER_INFINITY)

    assert_equal "infinity", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferencePageSizeOption.new(id: AppPreferencePageSizeOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferencePageSizeOption.new(id: 999)

    assert_nil option.name
  end
end
