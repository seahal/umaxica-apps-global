# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_theme_options
# Database name: principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserPreferenceThemeOptionTest < ActiveSupport::TestCase
  test "returns light for LIGHT id" do
    option = UserPreferenceThemeOption.new(id: UserPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "returns dark for DARK id" do
    option = UserPreferenceThemeOption.new(id: UserPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "returns system for SYSTEM id" do
    option = UserPreferenceThemeOption.new(id: UserPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "returns nil for NOTHING id" do
    option = UserPreferenceThemeOption.new(id: UserPreferenceThemeOption::NOTHING)

    assert_nil option.name
  end

  test "returns nil for unknown id" do
    option = UserPreferenceThemeOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      UserPreferenceThemeOption.where(id: UserPreferenceThemeOption::DEFAULTS).destroy_all
    end

    UserPreferenceThemeOption.ensure_defaults!

    assert UserPreferenceThemeOption.exists?(id: UserPreferenceThemeOption::NOTHING)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    UserPreferenceThemeOption.ensure_defaults!
    initial_count = UserPreferenceThemeOption.count

    UserPreferenceThemeOption.ensure_defaults!

    assert_equal initial_count, UserPreferenceThemeOption.count
  end

  test "DEFAULTS contains all expected values" do
    assert_equal [0, 1, 2, 3], UserPreferenceThemeOption::DEFAULTS
  end

  test "has_many association exists" do
    option = UserPreferenceThemeOption.new(id: 1)

    assert_respond_to option, :user_preference_themes
  end
end
