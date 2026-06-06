# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceConstantsTest < ActiveSupport::TestCase
  test "preference constants expose the expected keys" do
    assert_equal %w(lx ri tz ct), PreferenceConstants::PREFERENCE_KEYS
  end

  test "preference constants expose the expected defaults" do
    assert_equal(
      {
        "lx" => "ja",
        "ri" => "jp",
        "tz" => "asia/tokyo",
        "ct" => "sy",
      },
      PreferenceConstants::DEFAULT_PREFERENCES,
    )
  end

  test "preference constants stay frozen" do
    assert_predicate PreferenceConstants::PREFERENCE_KEYS, :frozen?
    assert_predicate PreferenceConstants::DEFAULT_PREFERENCES, :frozen?
  end
end
