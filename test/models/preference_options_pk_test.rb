# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceOptionsPkTest < ActiveSupport::TestCase
  test "AppPreferenceLanguageOption uses integer PK" do
    option = AppPreferenceLanguageOption.create!(id: 99)

    assert_equal 99, option.id
    assert_equal 99, option.reload.id
  end

  test "AppPreferenceRegionOption uses integer PK" do
    option = AppPreferenceRegionOption.create!(id: 99)

    assert_equal 99, option.id
  end

  test "ComPreferenceTimezoneOption uses integer PK" do
    option = ComPreferenceTimezoneOption.create!(id: 99)

    assert_equal 99, option.id
  end

  test "OrgPreferenceThemeOption uses integer PK" do
    option = OrgPreferenceThemeOption.create!(id: 99)

    assert_equal 99, option.id
  end

  test "Global fixture availability" do
    assert AppPreferenceLanguageOption.find(AppPreferenceLanguageOption::JA)
    assert AppPreferenceRegionOption.find(AppPreferenceRegionOption::US)
    assert AppPreferenceTimezoneOption.find(AppPreferenceTimezoneOption::ETC_UTC)
    assert AppPreferenceThemeOption.find(AppPreferenceThemeOption::LIGHT)
  end

  test "fixed theme option ids are available across preference surfaces" do
    assert AppPreferenceThemeOption.find(AppPreferenceThemeOption::LIGHT)
    assert AppPreferenceThemeOption.find(AppPreferenceThemeOption::DARK)
    assert AppPreferenceThemeOption.find(AppPreferenceThemeOption::SYSTEM)

    assert ComPreferenceThemeOption.find(ComPreferenceThemeOption::LIGHT)
    assert ComPreferenceThemeOption.find(ComPreferenceThemeOption::DARK)
    assert ComPreferenceThemeOption.find(ComPreferenceThemeOption::SYSTEM)

    assert OrgPreferenceThemeOption.find(OrgPreferenceThemeOption::LIGHT)
    assert OrgPreferenceThemeOption.find(OrgPreferenceThemeOption::DARK)
    assert OrgPreferenceThemeOption.find(OrgPreferenceThemeOption::SYSTEM)
  end
end
