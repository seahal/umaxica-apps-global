# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preferences
# Database name: principal
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  language        :string           default("ja"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_user_preferences_on_user_id  (user_id) UNIQUE
#
require "test_helper"

class UserPreferenceTest < ActiveSupport::TestCase
  test "belongs to user" do
    pref = user_preferences(:one)

    assert_predicate pref.user, :present?
  end

  test "has one language child" do
    pref = user_preferences(:one)

    assert_predicate pref.user_preference_language, :present?
  end

  test "has one timezone child" do
    pref = user_preferences(:one)

    assert_predicate pref.user_preference_timezone, :present?
  end

  test "has one region child" do
    pref = user_preferences(:one)

    assert_predicate pref.user_preference_region, :present?
  end

  test "has one theme child" do
    pref = user_preferences(:one)

    assert_predicate pref.user_preference_theme, :present?
  end

  test "user_id is unique" do
    pref = user_preferences(:one)
    duplicate = UserPreference.new(user_id: pref.user_id)

    assert_not duplicate.valid?
  end

  test "cookie consent defaults to false" do
    user = users(:sample_user)
    pref = UserPreference.new(user: user)

    assert_not pref.consented
    assert_not pref.functional
    assert_not pref.performant
    assert_not pref.targetable
  end

  test "1:1 relationship with user" do
    user = users(:one)

    assert_predicate user.user_preference, :present?
    assert_equal user.id, user.user_preference.user_id
  end
end
