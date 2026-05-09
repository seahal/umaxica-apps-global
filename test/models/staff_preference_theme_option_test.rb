# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_theme_options
# Database name: operator
#
#  id :bigint           not null, primary key
#
require "test_helper"

class StaffPreferenceThemeOptionTest < ActiveSupport::TestCase
  test "returns light for LIGHT id" do
    option = StaffPreferenceThemeOption.new(id: StaffPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "returns dark for DARK id" do
    option = StaffPreferenceThemeOption.new(id: StaffPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "returns system for SYSTEM id" do
    option = StaffPreferenceThemeOption.new(id: StaffPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "returns nil for NOTHING id" do
    option = StaffPreferenceThemeOption.new(id: StaffPreferenceThemeOption::NOTHING)

    assert_nil option.name
  end

  test "returns nil for unknown id" do
    option = StaffPreferenceThemeOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing records" do
    StaffPreferenceThemeOption.where(id: StaffPreferenceThemeOption::DEFAULTS).destroy_all

    StaffPreferenceThemeOption.ensure_defaults!

    assert StaffPreferenceThemeOption.exists?(id: StaffPreferenceThemeOption::NOTHING)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    StaffPreferenceThemeOption.ensure_defaults!
    initial_count = StaffPreferenceThemeOption.count

    StaffPreferenceThemeOption.ensure_defaults!

    assert_equal initial_count, StaffPreferenceThemeOption.count
  end

  test "DEFAULTS contains all expected values" do
    assert_equal [0, 1, 2, 3], StaffPreferenceThemeOption::DEFAULTS
  end

  test "has_many association exists" do
    option = StaffPreferenceThemeOption.new(id: 1)

    assert_respond_to option, :staff_preference_themes
  end
end
