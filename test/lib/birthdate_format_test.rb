# typed: false
# frozen_string_literal: true

require "test_helper"

class BirthdateFormatTest < ActiveSupport::TestCase
  test "accepts values inside the structural equivalence classes" do
    valid_values = %w(
      1900-01-01
      1999-12-31
      2000-02-29
      2000-02-31
      2000-04-31
      9999-12-31
    )

    valid_values.each do |value|
      assert_match BirthdateFormat::PATTERN, value, "#{value.inspect} should match birthdate format"
    end
  end

  test "accepts inclusive boundary values" do
    valid_values = %w(
      1900-01-01
      1900-12-31
      9999-01-01
      9999-12-31
      2000-01-01
      2000-12-31
    )

    valid_values.each do |value|
      assert_match BirthdateFormat::PATTERN, value, "#{value.inspect} should match birthdate format"
    end
  end

  test "rejects values immediately outside numeric boundaries" do
    invalid_values = %w(
      1899-12-31
      10000-01-01
      2000-00-01
      2000-13-01
      2000-01-00
      2000-01-32
      2000-00-00
      2000-13-32
    )

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end

  test "rejects years outside the four-digit 1900 through 9999 range" do
    invalid_values = %w(
      0-12-31
      100-01-01
      1899-12-31
      10000-01-01
    )

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end

  test "rejects months outside 01 through 12" do
    invalid_values = %w(
      2000-00-01
      2000-00-31
      2000-13-01
      2000-13-31
    )

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end

  test "rejects days outside 01 through 31" do
    invalid_values = %w(
      2000-01-00
      2000-12-00
      2000-01-32
      2000-12-32
    )

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end

  test "rejects non-canonical separators and padding" do
    invalid_values = [
      "2000-2-3",
      "2000-02-3",
      "2000-2-03",
      "20000203",
      "2000/02/03",
      "abcd-ef-gh",
    ]

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end

  test "rejects blank structural values" do
    invalid_values = [
      nil,
      "",
      " ",
    ]

    invalid_values.each do |value|
      assert_no_match BirthdateFormat::PATTERN, value, "#{value.inspect} should not match birthdate format"
    end
  end
end
