# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceAdoptionTest < ActiveSupport::TestCase
  class Harness
    include PreferenceAdoption

    attr_accessor :preference_class_value

    def preference_class = preference_class_value

    def with_preference_writing_connection(*) = yield

    def preference_connection_class(*) = nil

    def invoke(name, ...) = send(name, ...)
  end

  class FlatPreference
    attr_accessor :language, :region, :timezone, :theme, :currency, :updates

    def initialize(**attributes)
      attributes.each { |name, value| public_send(:"#{name}=", value) }
    end

    def update!(attributes) = self.updates = attributes
  end

  class CookiePreference
    attr_accessor :consented, :functional, :performant, :targetable, :updates

    def update!(attributes) = self.updates = attributes
  end

  # When the browser and the account have each explicitly set the same key, the
  # reconciliation compares recency rather than preferring a side. A principal child
  # with no timestamp is treated as the winner so an unstamped legacy row is not
  # overwritten by a browser marker.
  test "key_recency_winner compares the two sides by recency" do
    harness = Harness.new
    older = Struct.new(:updated_at).new(2.hours.ago)
    newer = Struct.new(:updated_at).new(1.minute.ago)
    unstamped = Struct.new(:updated_at).new(nil)

    assert_equal :browser, harness.invoke(:key_recency_winner, newer, older)
    assert_equal :principal, harness.invoke(:key_recency_winner, older, newer)
    assert_equal :principal, harness.invoke(:key_recency_winner, newer, unstamped)
    assert_equal :principal, harness.invoke(:key_recency_winner, unstamped, newer)
    assert_equal :principal, harness.invoke(:key_recency_winner, older, older)
  end

  test "resource mappings cover every preference surface and unknown classes" do
    harness = Harness.new

    harness.preference_class_value = AppPreference

    assert_equal [ClientPreference, :user_id], harness.invoke(:resource_preference_mapping)
    assert_equal "Client", harness.invoke(:resource_pref_prefix)

    harness.preference_class_value = OrgPreference

    assert_equal [OperatorPreference, :staff_id], harness.invoke(:resource_preference_mapping)
    assert_equal "Operator", harness.invoke(:resource_pref_prefix)

    harness.preference_class_value = ComPreference

    assert_equal [VisitorPreference, :visitor_id], harness.invoke(:resource_preference_mapping)
    assert_equal "Visitor", harness.invoke(:resource_pref_prefix)

    harness.preference_class_value = String

    assert_equal [nil, nil], harness.invoke(:resource_preference_mapping)
    assert_nil harness.invoke(:resource_pref_prefix)
  end

  test "local preference snapshot and flat copy preserve supported values" do
    source = FlatPreference.new(language: "ja", region: "jp", timezone: "Asia/Tokyo", theme: "dark")
    target = FlatPreference.new
    harness = Harness.new

    snapshot = harness.invoke(:preference_snapshot_for, source)
    harness.invoke(:copy_flat_preference_values!, source, target)

    assert_equal({ language: "ja", region: "jp", timezone: "Asia/Tokyo", theme: "dark" }, snapshot)
    assert_equal snapshot, target.updates
    assert_nil harness.invoke(:preference_snapshot_for, nil)
  end

  test "direct cookie consent copies without a database connection owner" do
    source = CookiePreference.new
    source.consented = true
    source.functional = false
    source.performant = true
    source.targetable = false
    target = CookiePreference.new

    Harness.new.invoke(:copy_cookie_consent!, source, target, nil, nil)

    assert_equal(
      { consented: true, functional: false, performant: true, targetable: false },
      target.updates,
    )
  end

  test "cross database option resolution returns matching ids and nil for no match" do
    source_option = Struct.new(:name).new("Dark")
    source_child = Struct.new(:option_id, :option).new("source-id", source_option)
    matching = Struct.new(:id, :name).new("target-id", "dark")
    target_class = Class.new
    target_class.define_singleton_method(:find_each) { |&block| [matching].each(&block) }
    harness = Harness.new

    assert_equal "target-id", harness.invoke(:resolve_cross_db_option_id, source_child, target_class)

    target_class.define_singleton_method(:find_each) { nil }

    assert_nil harness.invoke(:resolve_cross_db_option_id, source_child, target_class)
  end

  test "theme codes normalize known values and reject unknown values" do
    harness = Harness.new

    assert_equal "li", harness.invoke(:preference_theme_short_code, "Light")
    assert_equal "dr", harness.invoke(:preference_theme_short_code, "DARK")
    assert_equal "sy", harness.invoke(:preference_theme_short_code, "system")
    assert_nil harness.invoke(:preference_theme_short_code, "unknown")
  end

  test "touch target updates timestamp without a connection owner" do
    target = Struct.new(:updates) do
      def update!(attributes) = self.updates = attributes
    end.new

    Harness.new.invoke(:touch_target!, target)

    assert_instance_of ActiveSupport::TimeWithZone, target.updates.fetch(:updated_at)
  end
end
