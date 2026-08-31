# typed: false
# frozen_string_literal: true

require "test_helper"

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

  test "apply_localization_preferences uses actor language" do
    harness = Harness.new
    preferences = Struct.new(:language).new(:en)

    Actor.stub(:preferences, preferences) do
      harness.send(:apply_localization_preferences)

      assert_equal :en, I18n.locale
    end
  end

  test "apply_localization_preferences falls back to the default locale when language is blank" do
    harness = Harness.new
    preferences = Struct.new(:language).new(nil)

    Actor.stub(:preferences, preferences) do
      harness.send(:apply_localization_preferences)

      assert_equal I18n.default_locale, I18n.locale
    end
  end

  # The request time zone belongs to PreferenceGlobal#set_timezone, which also
  # sees the ?tz overlay and the preference cookie. Assigning it here as well
  # would let the actor record override the narrower, more specific source.
  test "apply_localization_preferences leaves the time zone alone" do
    harness = Harness.new
    preferences = Struct.new(:language, :timezone).new(:en, "America/New_York")
    Time.zone = "Etc/UTC" # rubocop:disable Rails/TimeZoneAssignment

    Actor.stub(:preferences, preferences) do
      harness.send(:apply_localization_preferences)

      assert_equal "Etc/UTC", Time.zone.name
    end
  end
end
