# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_time_format_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceTimeFormatOptionTest < ActiveSupport::TestCase
  test "name returns 24 for HOUR_24 id" do
    option = OrgPreferenceTimeFormatOption.new(id: OrgPreferenceTimeFormatOption::HOUR_24)

    assert_equal "24", option.name
  end

  test "name returns 12 for HOUR_12 id" do
    option = OrgPreferenceTimeFormatOption.new(id: OrgPreferenceTimeFormatOption::HOUR_12)

    assert_equal "12", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OrgPreferenceTimeFormatOption.new(id: OrgPreferenceTimeFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceTimeFormatOption.new(id: 999)

    assert_nil option.name
  end
end
