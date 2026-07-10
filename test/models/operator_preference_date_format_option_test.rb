# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_date_format_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = OperatorPreferenceDateFormatOption.new(id: OperatorPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = OperatorPreferenceDateFormatOption.new(id: OperatorPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = OperatorPreferenceDateFormatOption.new(id: OperatorPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceDateFormatOption.new(id: OperatorPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
