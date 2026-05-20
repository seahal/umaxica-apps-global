# typed: false
# == Schema Information
#
# Table name: app_preference_cookies
# Database name: app_setting
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  performant      :boolean          default(FALSE), not null
#  targetable      :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  preference_id   :bigint           not null
#
# Indexes
#
#  index_app_preference_cookies_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (preference_id => app_preferences.id)
#

# frozen_string_literal: true

require "test_helper"

class AppPreferenceCookieTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
    @preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
  end

  %i(targetable performant functional).each do |flag|
    test "validates #{flag} inclusion" do
      cookie = AppPreferenceCookie.new(preference: @preference)
      cookie.assign_attributes(flag => nil)

      assert_not cookie.valid?
      assert_includes cookie.errors[flag], "は一覧にありません"
    end
  end

  test "persists every boolean flag combination" do
    [false, true].repeated_permutation(3).each do |targetable, performant, functional|
      cookie = AppPreferenceCookie.new(
        preference: @preference,
        targetable: targetable,
        performant: performant,
        functional: functional,
      )

      assert cookie.save, "combo failed: targetable=#{targetable} performant=#{performant} functional=#{functional}"
      cookie.destroy!
    end
  end

  test "belongs to preference" do
    cookie = AppPreferenceCookie.new(targetable: true)

    assert_not cookie.valid?
    assert_includes cookie.errors[:preference], "を入力してください"
  end

  test "has false as default for all flags" do
    cookie = AppPreferenceCookie.create!(preference: @preference)

    assert_not cookie.targetable
    assert_not cookie.performant
    assert_not cookie.functional
  end

  test "loading an existing cookie preserves stored flags" do
    cookie = AppPreferenceCookie.create!(
      preference: @preference,
      targetable: true,
      performant: true,
      functional: true,
      consented: true,
    )

    loaded = AppPreferenceCookie.find(cookie.id)

    assert loaded.targetable
    assert loaded.performant
    assert loaded.functional
    assert loaded.consented
  end

  test "set_defaults fills nil booleans on new records" do
    cookie = AppPreferenceCookie.new(preference: @preference)
    cookie.targetable = nil
    cookie.performant = nil
    cookie.functional = nil
    cookie.consented = nil

    cookie.send(:set_defaults)

    assert_not cookie.targetable
    assert_not cookie.performant
    assert_not cookie.functional
    assert_not cookie.consented
  end
end
