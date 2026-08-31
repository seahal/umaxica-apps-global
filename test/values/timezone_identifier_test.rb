# typed: false
# frozen_string_literal: true

require "test_helper"

class TimezoneIdentifierTest < ActiveSupport::TestCase
  test "normalize folds the short aliases carried in the tz parameter and cookie" do
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("jst")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("asia/tokyo")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("Asia/Tokyo")
    assert_equal "Etc/UTC", TimezoneIdentifier.normalize("utc")
    assert_equal "Etc/UTC", TimezoneIdentifier.normalize("etc/utc")
  end

  test "normalize returns the canonical IANA name for other known zones" do
    assert_equal "America/New_York", TimezoneIdentifier.normalize("America/New_York")
    assert_equal "America/New_York", TimezoneIdentifier.normalize("  America/New_York  ")
    assert_equal "Europe/Paris", TimezoneIdentifier.normalize("Paris")
  end

  # The tz query parameter and the preference cookie are downcased in transit,
  # so a lowercase IANA name has to resolve to the same zone as the canonical
  # spelling; ActiveSupport::TimeZone[] alone rejects it.
  test "normalize matches identifiers case-insensitively" do
    assert_equal "America/New_York", TimezoneIdentifier.normalize("america/new_york")
    assert_equal "Europe/Paris", TimezoneIdentifier.normalize("EUROPE/PARIS")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("tokyo")
  end

  test "normalize rejects unknown values instead of passing them through" do
    assert_nil TimezoneIdentifier.normalize("Invalid/Zone")
    assert_nil TimezoneIdentifier.normalize("asia/tokyo; DROP")
    assert_nil TimezoneIdentifier.normalize("")
    assert_nil TimezoneIdentifier.normalize(nil)
  end

  test "valid? reports whether a value names a real zone" do
    assert TimezoneIdentifier.valid?("jst")
    assert_not TimezoneIdentifier.valid?("Invalid/Zone")
  end

  test "resolve takes the first usable candidate" do
    assert_equal "Etc/UTC", TimezoneIdentifier.resolve(nil, "Invalid/Zone", "utc", "jst")
  end

  test "resolve falls back only to the default the caller names" do
    assert_equal TimezoneIdentifier::DEFAULT, TimezoneIdentifier.resolve("Invalid/Zone")
    assert_equal "Etc/UTC", TimezoneIdentifier.resolve(nil, default: "Etc/UTC")
  end
end
