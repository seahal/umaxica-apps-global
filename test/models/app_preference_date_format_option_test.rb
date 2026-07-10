# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_date_format_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = AppPreferenceDateFormatOption.new(id: AppPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = AppPreferenceDateFormatOption.new(id: AppPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = AppPreferenceDateFormatOption.new(id: AppPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceDateFormatOption.new(id: AppPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
