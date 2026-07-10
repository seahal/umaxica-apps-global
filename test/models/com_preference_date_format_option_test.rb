# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_date_format_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = ComPreferenceDateFormatOption.new(id: ComPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = ComPreferenceDateFormatOption.new(id: ComPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = ComPreferenceDateFormatOption.new(id: ComPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ComPreferenceDateFormatOption.new(id: ComPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
