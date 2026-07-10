# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_date_format_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = VisitorPreferenceDateFormatOption.new(id: VisitorPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = VisitorPreferenceDateFormatOption.new(id: VisitorPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = VisitorPreferenceDateFormatOption.new(id: VisitorPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceDateFormatOption.new(id: VisitorPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
