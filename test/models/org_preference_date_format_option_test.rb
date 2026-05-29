# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_date_format_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = OrgPreferenceDateFormatOption.new(id: OrgPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = OrgPreferenceDateFormatOption.new(id: OrgPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = OrgPreferenceDateFormatOption.new(id: OrgPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OrgPreferenceDateFormatOption.new(id: OrgPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
