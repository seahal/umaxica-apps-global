# typed: false
# == Schema Information
#
# Table name: app_preference_theme_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class AppPreferenceThemeOptionTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "can be created" do
    option = AppPreferenceThemeOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many app_preference_themes" do
    option = AppPreferenceThemeOption.create!(id: 99)
    preference = AppPreference.create!
    theme = AppPreferenceTheme.create!(preference: preference, option: option)

    assert_includes option.app_preference_themes, theme
  end

  test "restricts deletion when associated records exist" do
    option = AppPreferenceThemeOption.create!(id: 99)
    preference = AppPreference.create!
    AppPreferenceTheme.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end
end
