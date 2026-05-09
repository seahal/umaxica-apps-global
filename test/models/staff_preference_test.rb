# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preferences
# Database name: operator
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
#  staff_id        :bigint           not null
#
# Indexes
#
#  index_staff_preferences_on_staff_id  (staff_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => staffs.id)
#
require "test_helper"

class StaffPreferenceTest < ActiveSupport::TestCase
  test "belongs to staff" do
    pref = staff_preferences(:one)

    assert_predicate pref.staff, :present?
  end

  test "has one language child" do
    pref = staff_preferences(:one)

    assert_predicate pref.staff_preference_language, :present?
  end

  test "has one timezone child" do
    pref = staff_preferences(:one)

    assert_predicate pref.staff_preference_timezone, :present?
  end

  test "has one region child" do
    pref = staff_preferences(:one)

    assert_predicate pref.staff_preference_region, :present?
  end

  test "has one theme child" do
    pref = staff_preferences(:one)

    assert_predicate pref.staff_preference_theme, :present?
  end

  test "staff_id is unique" do
    pref = staff_preferences(:one)
    duplicate = StaffPreference.new(staff_id: pref.staff_id)

    assert_not duplicate.valid?
  end

  test "cookie consent defaults to false" do
    staff = staffs(:sample_staff)
    pref = StaffPreference.new(staff: staff)

    assert_not pref.consented
    assert_not pref.functional
    assert_not pref.performant
    assert_not pref.targetable
  end

  test "1:1 relationship with staff" do
    staff = staffs(:one)

    assert_predicate staff.staff_preference, :present?
    assert_equal staff.id, staff.staff_preference.staff_id
  end
end
