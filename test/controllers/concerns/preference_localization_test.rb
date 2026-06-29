# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class PreferenceLocalizationTest < ActiveSupport::TestCase
  class Harness
    include PreferenceLocalization
  end

  setup do
    @original_locale = I18n.locale
    @original_timezone = Time.zone
  end

  teardown do
    I18n.locale = @original_locale # rubocop:disable Rails/I18nLocaleAssignment
    Time.zone = @original_timezone # rubocop:disable Rails/TimeZoneAssignment
  end

  test "apply_localization_preferences uses actor language and timezone" do
    harness = Harness.new
    preferences = Struct.new(:language, :timezone).new(:en, "Asia/Tokyo")

    Actor.stub(:preferences, preferences) do
      harness.send(:apply_localization_preferences)

      assert_equal :en, I18n.locale
      assert_equal "Asia/Tokyo", Time.zone.name
    end
  end

  test "apply_localization_preferences falls back when timezone is invalid" do
    harness = Harness.new
    preferences = Struct.new(:language, :timezone).new(:en, "not_a_zone")

    Actor.stub(:preferences, preferences) do
      harness.send(:apply_localization_preferences)

      assert_equal I18n.default_locale, I18n.locale
      assert_equal "Etc/UTC", Time.zone.name
    end
  end

  test "localization_timezone preserves unknown but valid timezone names" do
    harness = Harness.new
    preferences = Struct.new(:timezone).new("America/New_York")

    Actor.stub(:preferences, preferences) do
      assert_equal "America/New_York", harness.send(:localization_timezone)
    end
  end
end
