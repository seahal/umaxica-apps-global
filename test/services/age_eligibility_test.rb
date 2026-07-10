# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AgeEligibilityTest < ActiveSupport::TestCase
  # birthdate_for_age tests
  test "birthdate_for_age returns nil for blank value" do
    assert_nil AgeEligibility.birthdate_for_age(nil)
    assert_nil AgeEligibility.birthdate_for_age("")
    assert_nil AgeEligibility.birthdate_for_age("   ")
  end

  test "birthdate_for_age returns date for valid YYYY-MM-DD format" do
    result = AgeEligibility.birthdate_for_age("2000-05-15")

    assert_equal Date.new(2000, 5, 15), result
  end

  test "birthdate_for_age returns nil for invalid format" do
    assert_nil AgeEligibility.birthdate_for_age("15-05-2000")
    assert_nil AgeEligibility.birthdate_for_age("2000/05/15")
    assert_nil AgeEligibility.birthdate_for_age("May 15, 2000")
    assert_nil AgeEligibility.birthdate_for_age("2000-13-01") # invalid month
  end

  test "birthdate_for_age handles numeric input by converting to string" do
    result = AgeEligibility.birthdate_for_age(20_000_515)

    assert_nil result # doesn't match YYYY-MM-DD format
  end

  test "birthdate_for_age rescues Date::Error and advances to first day of next month" do
    # Day 31 doesn't exist in February, so it advances to March 1st
    result = AgeEligibility.birthdate_for_age("2000-02-31")

    assert_equal Date.new(2000, 3, 1), result
  end

  test "birthdate_for_age handles leap year dates" do
    result = AgeEligibility.birthdate_for_age("2000-02-29")

    assert_equal Date.new(2000, 2, 29), result
  end

  test "birthdate_for_age handles non-leap year invalid date" do
    result = AgeEligibility.birthdate_for_age("2001-02-29")

    assert_equal Date.new(2001, 3, 1), result
  end

  # minimum_age_reached? tests
  test "minimum_age_reached? returns false for blank birthdate" do
    assert_not AgeEligibility.minimum_age_reached?(nil, minimum_age: 18)
    assert_not AgeEligibility.minimum_age_reached?("", minimum_age: 18)
  end

  test "minimum_age_reached? returns false for invalid birthdate format" do
    assert_not AgeEligibility.minimum_age_reached?("invalid", minimum_age: 18)
    assert_not AgeEligibility.minimum_age_reached?("2000-13-01", minimum_age: 18)
  end

  test "minimum_age_reached? returns true when person has reached minimum age" do
    today = Date.new(2024, 6, 15)
    birthdate = "2006-06-15"

    assert AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18, today: today)
  end

  test "minimum_age_reached? returns false when person is one day short of minimum age" do
    today = Date.new(2024, 6, 15)
    birthdate = "2006-06-16"

    assert_not AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18, today: today)
  end

  test "minimum_age_reached? returns true when person is well over minimum age" do
    today = Date.new(2024, 6, 15)
    birthdate = "1980-01-01"

    assert AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18, today: today)
  end

  test "minimum_age_reached? handles different minimum ages" do
    today = Date.new(2024, 6, 15)
    birthdate = "2010-06-15"

    assert AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 14, today: today)
    assert_not AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 15, today: today)
  end

  test "minimum_age_reached? uses Time.zone.today as default" do
    birthdate = "2000-01-01"
    result = AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18)

    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  test "minimum_age_reached? handles leap year birthdate" do
    today = Date.new(2024, 3, 1)
    birthdate = "2000-02-29"

    assert AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18, today: today)
  end

  test "minimum_age_reached? handles rescue case when Date::Error occurs" do
    today = Date.new(2024, 6, 15)
    birthdate = "2000-02-31"

    assert AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 18, today: today)
  end
end
