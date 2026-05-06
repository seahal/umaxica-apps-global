# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceConstantsTest < ActiveSupport::TestCase
  test "preference constants expose the expected keys" do
    assert_equal %w(lx ri tz ct), Preference::Constants::PREFERENCE_KEYS
  end

  test "preference constants expose the expected defaults" do
    assert_equal(
      {
        "lx" => "ja",
        "ri" => "jp",
        "tz" => "jst",
        "ct" => "sy",
      },
      Preference::Constants::DEFAULT_PREFERENCES,
    )
  end

  test "preference constants stay frozen" do
    assert_predicate Preference::Constants::PREFERENCE_KEYS, :frozen?
    assert_predicate Preference::Constants::DEFAULT_PREFERENCES, :frozen?
  end
end
