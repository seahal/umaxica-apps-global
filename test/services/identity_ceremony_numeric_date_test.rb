# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class IdentityCeremonyNumericDateTest < ActiveSupport::TestCase
  REFERENCE_EPOCH = Time.utc(2024, 1, 2, 3, 4, 5).to_i

  test "value converts a Time instance to its epoch integer" do
    assert_equal REFERENCE_EPOCH, IdentityCeremonyNumericDate.value(Time.utc(2024, 1, 2, 3, 4, 5))
  end

  test "value converts a DateTime instance to its epoch integer" do
    assert_equal REFERENCE_EPOCH, IdentityCeremonyNumericDate.value(DateTime.new(2024, 1, 2, 3, 4, 5))
  end

  test "value converts an ActiveSupport::TimeWithZone to its epoch integer" do
    twz = Time.utc(2024, 1, 2, 3, 4, 5).in_time_zone

    assert_equal REFERENCE_EPOCH, IdentityCeremonyNumericDate.value(twz)
  end

  test "value returns an Integer input unchanged" do
    assert_equal REFERENCE_EPOCH, IdentityCeremonyNumericDate.value(REFERENCE_EPOCH)
  end

  test "value parses a numeric string in base 10" do
    assert_equal REFERENCE_EPOCH, IdentityCeremonyNumericDate.value(REFERENCE_EPOCH.to_s)
  end

  test "value rejects a non-integer Numeric input because base conversion requires a String" do
    assert_raises(StandardError) do
      IdentityCeremonyNumericDate.value(3.5)
    end
  end
end
