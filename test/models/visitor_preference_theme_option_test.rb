# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_theme_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_theme_options_on_id  (id) UNIQUE
#
require "test_helper"

class VisitorPreferenceThemeOptionTest < ActiveSupport::TestCase
  fixtures_only :visitor_preference_theme_options

  test "has correct constants" do
    assert_equal 0, VisitorPreferenceThemeOption::SYSTEM
    assert_equal 1, VisitorPreferenceThemeOption::LIGHT
    assert_equal 2, VisitorPreferenceThemeOption::DARK
    assert_equal 3, VisitorPreferenceThemeOption::LEGACY_SYSTEM
  end

  test "can load system option from db" do
    option = VisitorPreferenceThemeOption.find(VisitorPreferenceThemeOption::SYSTEM)

    assert_equal 0, option.id
  end

  test "name returns system for SYSTEM id" do
    option = VisitorPreferenceThemeOption.find_or_create_by!(id: VisitorPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "name returns system for LEGACY_SYSTEM id" do
    option = VisitorPreferenceThemeOption.find_or_create_by!(id: VisitorPreferenceThemeOption::LEGACY_SYSTEM)

    assert_equal "system", option.name
  end

  test "name returns light for LIGHT id" do
    option = VisitorPreferenceThemeOption.find_or_create_by!(id: VisitorPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "name returns dark for DARK id" do
    option = VisitorPreferenceThemeOption.find_or_create_by!(id: VisitorPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "VisitorPreferenceThemeOption.count" do
      VisitorPreferenceThemeOption.ensure_defaults!
    end
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceThemeOption.new(id: 99)

    assert_nil option.name
  end
end
