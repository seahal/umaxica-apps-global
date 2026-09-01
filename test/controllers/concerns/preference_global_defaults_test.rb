# typed: false
# frozen_string_literal: true

require "test_helper"

# The allowed regions are read from the surface's own option table so a region
# added there is accepted without a code change, and an option table that is
# missing or empty falls back to the compiled allowlist rather than accepting
# every value. The theme and language readers are the documented defaults a
# surface answers with before any preference is resolved.
class PreferenceGlobalDefaultsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include PreferenceGlobal

    attr_accessor :preferences_value, :prefix

    def initialize
      @prefix = :app
    end

    def preference_prefix = prefix

    def invoke(name, ...) = send(name, ...)

    def prepare_preferences(value)
      @preferences = value
    end
  end

  setup do
    @harness = Harness.new
  end

  test "with no resolved preference the compiled allowlist is used" do
    assert_equal PreferenceGlobal::ALLOWED_REGION_VALUES, @harness.invoke(:allowed_region_values)
  end

  test "an option table that lists no usable name falls back to the compiled allowlist" do
    @harness.prepare_preferences(Object.new)

    empty_option_class = Class.new do
      def self.filter_map(&) = []
    end

    PreferenceClassRegistry.stub(:option_class, empty_option_class) do
      assert_equal PreferenceGlobal::ALLOWED_REGION_VALUES, @harness.invoke(:allowed_region_values)
    end
  end

  test "an unregistered surface prefix falls back to the compiled allowlist rather than raising" do
    @harness.prepare_preferences(Object.new)
    raising = ->(*) { raise KeyError, "no option class" }

    PreferenceClassRegistry.stub(:option_class, raising) do
      assert_equal PreferenceGlobal::ALLOWED_REGION_VALUES, @harness.invoke(:allowed_region_values)
    end
  end

  test "the theme and language readers answer the documented defaults" do
    assert_equal "sy", @harness.invoke(:get_theme)
    assert_equal I18n.locale.to_s, @harness.invoke(:get_language)
  end
end
