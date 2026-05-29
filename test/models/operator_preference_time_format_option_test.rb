# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_time_format_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceTimeFormatOptionTest < ActiveSupport::TestCase
  test "name returns hour_24 for HOUR_24 id" do
    option = OperatorPreferenceTimeFormatOption.new(id: OperatorPreferenceTimeFormatOption::HOUR_24)

    assert_equal "hour_24", option.name
  end

  test "name returns hour_12 for HOUR_12 id" do
    option = OperatorPreferenceTimeFormatOption.new(id: OperatorPreferenceTimeFormatOption::HOUR_12)

    assert_equal "hour_12", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceTimeFormatOption.new(id: OperatorPreferenceTimeFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceTimeFormatOption.new(id: 999)

    assert_nil option.name
  end
end
