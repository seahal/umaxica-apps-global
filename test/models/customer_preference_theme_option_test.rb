# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_theme_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class CustomerPreferenceThemeOptionTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, CustomerPreferenceThemeOption::SYSTEM
    assert_equal 1, CustomerPreferenceThemeOption::LIGHT
    assert_equal 2, CustomerPreferenceThemeOption::DARK
    assert_equal 3, CustomerPreferenceThemeOption::LEGACY_SYSTEM
  end

  test "can load system option from db" do
    option = CustomerPreferenceThemeOption.find(CustomerPreferenceThemeOption::SYSTEM)

    assert_equal 0, option.id
  end

  test "name returns system for SYSTEM id" do
    option = CustomerPreferenceThemeOption.find_or_create_by!(id: CustomerPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "name returns system for LEGACY_SYSTEM id" do
    option = CustomerPreferenceThemeOption.find_or_create_by!(id: CustomerPreferenceThemeOption::LEGACY_SYSTEM)

    assert_equal "system", option.name
  end

  test "name returns light for LIGHT id" do
    option = CustomerPreferenceThemeOption.find_or_create_by!(id: CustomerPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "name returns dark for DARK id" do
    option = CustomerPreferenceThemeOption.find_or_create_by!(id: CustomerPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "CustomerPreferenceThemeOption.count" do
      CustomerPreferenceThemeOption.ensure_defaults!
    end
  end
end
