# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceAdoptionBranchCoverageTest < ActiveSupport::TestCase
  class Harness
    include PreferenceAdoption

    attr_accessor :preference_class_value, :preferences

    def preference_class = preference_class_value

    def preference_prefix(*) = "App"

    def resource_pref_prefix = "Client"

    def with_preference_writing_connection(*) = yield

    def preference_connection_class(*) = nil

    def invoke(name, ...) = send(name, ...)
  end

  class BarePreference
    def initialize(children = {}) = @children = children

    def update!(_values) = true

    def method_missing(name, *args, **kwargs)
      key = name.to_s
      return @children[key] if @children.key?(key)
      return nil if key.end_with?("_cookie")

      super
    end

    def respond_to_missing?(name, include_private = false) = @children.key?(name.to_s) || super
  end

  test "adoption entry guards and rescue are nonfatal" do
    h = Harness.new
    h.preference_class_value = String

    assert_nil h.invoke(:adopt_preference_for!, Object.new)
    h.preference_class_value = AppPreference

    assert_nil h.invoke(:adopt_preference_for!, nil)
    h.preferences = nil

    assert_nil h.invoke(:adopt_preference_for!, Object.new)
    h.preferences = Object.new
    h.define_singleton_method(:find_or_create_resource_preference!) { |_resource| raise StandardError, "boom" }

    assert h.invoke(:adopt_preference_for!, Object.new)
  end

  test "rotated adoption guards and missing target are nonfatal" do
    h = Harness.new
    h.preference_class_value = String

    assert_nil h.invoke(:adopt_rotated_preference!, Object.new, Object.new)
    h.preference_class_value = AppPreference

    assert_nil h.invoke(:adopt_rotated_preference!, nil, Object.new)
    assert_nil h.invoke(:adopt_rotated_preference!, Object.new, nil)
    h.define_singleton_method(:find_resource_preference) { |_resource| nil }

    assert_nil h.invoke(:adopt_rotated_preference!, Object.new, Object.new)
  end

  test "child reconciliation and copy guards cover absent associations" do
    h = Harness.new
    h.preferences = BarePreference.new
    target = BarePreference.new

    assert_nil h.invoke(:reconcile_preference_key!, target, :language)
    source_child = Struct.new(:option_id).new(nil)

    assert_nil h.invoke(
      :copy_single_child!, Object.new, target, "Client", :language, source_child: source_child,
                                                                    mark_explicit: false,
    )
    source_child.option_id = 1

    assert_nil h.invoke(
      :copy_single_child!, Object.new, Object.new, "Client", :language, source_child: source_child,
                                                                        mark_explicit: false,
    )
  end

  test "flat reconciliation and copy skip unsupported or blank snapshots" do
    h = Harness.new
    target = Object.new

    assert_nil h.invoke(:reconcile_flat_preference_values!, target)
    source = BarePreference.new
    target = BarePreference.new

    assert_nil h.invoke(:copy_flat_preference_values!, source, target)
    assert h.invoke(:copy_preference_values!, source, target, "Client")
  end

  test "copy preference skips children without options, associations, or mapped ids" do
    h = Harness.new
    source = BarePreference.new("plain_preference_language" => Struct.new(:option_id).new(nil))
    target = BarePreference.new

    assert h.invoke(:copy_preference_values!, source, target, "Client")
    source = BarePreference.new("plain_preference_language" => Struct.new(:option_id).new(1))

    assert h.invoke(:copy_preference_values!, source, target, "Client")
  end

  test "unknown resource preference class maps to no class" do
    h = Harness.new
    h.preference_class_value = String

    assert_equal [nil, nil], h.invoke(:resource_preference_mapping)
  end
end
