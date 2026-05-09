# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::CommonHelperTest < ActionView::TestCase
  setup do
    extend Sign::CommonHelper
  end

  test "to_localetime converts to JST for jst timezone" do
    test_time = Time.parse("2024-01-01 00:00:00 UTC")

    result = to_localetime(test_time, "jst")

    assert_equal "JST", result.zone
  end

  test "to_localetime converts to UTC by default" do
    test_time = Time.parse("2024-01-01 00:00:00 UTC")

    result = to_localetime(test_time)

    assert_equal "UTC", result.zone
  end

  test "to_localetime returns nil when time is nil" do
    assert_nil to_localetime(nil)
  end

  test "localized_session_timestamp falls back to strftime when short format is unavailable" do
    test_time = Time.zone.parse("2024-01-01 12:34:00 UTC")

    I18n.stub(:t, nil) do
      assert_equal "2024/01/01 12:34", localized_session_timestamp(test_time)
    end
  end

  test "get_timezone returns jst" do
    assert_equal "jst", get_timezone
  end

  test "get_language returns ja" do
    assert_equal "ja", get_language
  end

  test "get_region returns jp" do
    assert_equal "jp", get_region
  end

  test "get_theme returns sy" do
    assert_equal "sy", get_theme
  end
end
