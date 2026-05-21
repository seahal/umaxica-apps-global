# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_theme_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceThemeOptionTest < ActiveSupport::TestCase
  test "returns light for LIGHT id" do
    option = ClientPreferenceThemeOption.new(id: ClientPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "returns dark for DARK id" do
    option = ClientPreferenceThemeOption.new(id: ClientPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "returns system for SYSTEM id" do
    option = ClientPreferenceThemeOption.new(id: ClientPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "returns nil for NOTHING id" do
    option = ClientPreferenceThemeOption.new(id: ClientPreferenceThemeOption::NOTHING)

    assert_nil option.name
  end

  test "returns nil for unknown id" do
    option = ClientPreferenceThemeOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      ClientPreferenceThemeOption.where(id: ClientPreferenceThemeOption::DEFAULTS).destroy_all
    end

    ClientPreferenceThemeOption.ensure_defaults!

    assert ClientPreferenceThemeOption.exists?(id: ClientPreferenceThemeOption::NOTHING)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    ClientPreferenceThemeOption.ensure_defaults!
    initial_count = ClientPreferenceThemeOption.count

    ClientPreferenceThemeOption.ensure_defaults!

    assert_equal initial_count, ClientPreferenceThemeOption.count
  end

  test "DEFAULTS contains all expected values" do
    assert_equal [0, 1, 2, 3], ClientPreferenceThemeOption::DEFAULTS
  end

  test "has_many association exists" do
    option = ClientPreferenceThemeOption.new(id: 1)

    assert_respond_to option, :client_preference_themes
  end
end
