# typed: false
# frozen_string_literal: true

require_relative "core_test"

class PreferenceCoreThresholdCoverageTest < ActiveSupport::TestCase
  def controller
    PreferenceCoreHarness.new
  end

  test "locale and timezone normalizers cover blank and unsupported values" do
    c = controller

    assert_nil c.pin_locale_to_saved_language(nil)
    blank = Struct.new(:option_id).new("")

    assert_nil c.pin_locale_to_saved_language(blank)
    assert_nil c.send(:resolved_writable_timezone, Struct.new(:option_id).new("missing"), "not/a-zone")
    assert_equal "Etc/UTC", c.send(:resolved_writable_timezone, Struct.new(:option_id).new("missing"), "UTC")
  end

  test "preference mutation guards reject absent records and attributes" do
    c = controller
    assert_raises(PreferenceOperationError) {
      c.send(:update_preference_child_dual_write!, nil, {}, option_type: :language, audit_event: "x")
    }
    assert_raises(PreferenceOperationError) { c.send(:update_preference_cookie_dual_write!, nil, {}, audit_event: "x") }
    c.instance_variable_set(:@preferences, nil)

    assert_nil c.send(:mark_preference_field_explicit!, :language)
    c.instance_variable_set(:@preferences, Object.new)

    assert_nil c.send(:mark_preference_field_explicit!, :language)
  end

  test "refresh loaders take persisted and nonpersisted association paths" do
    c = controller
    association = Struct.new(:loaded?) { def reload = true }.new(true)
    pref = Struct.new(:persisted?) do
      def association(*) = @association

      def association=(value)
        @association = value
      end

      def blank? = false
    end.new(true)
    pref.association = association
    c.define_singleton_method(:ensure_preferences_record) { pref }
    c.define_singleton_method(:load_or_create_preference_child) { |type, attrs| [type, attrs] }

    assert_equal ["Language", {}], c.send(:load_or_refresh_preference_child, "Language")
    c.define_singleton_method(:load_or_build_preference_child) { |type| type }

    assert_equal "Region", c.send(:load_or_refresh_preference_child_for_edit, "Region")
  end

  test "preference response defaults fill missing snapshot fields" do
    c = controller
    c.instance_variable_set(:@preferences, Object.new)
    c.define_singleton_method(:resolved_preference_snapshot) { |_| {} }
    c.define_singleton_method(:resolved_preference_cookie) { |_| { consented: false } }
    payload = c.send(:preference_response_payload)

    assert_equal Actor::Preference::DEFAULTS[:language], payload[:lx]
    assert_equal "jpy", payload[:cu]
    assert_not payload[:consented]
  end
end
