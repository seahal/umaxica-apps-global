# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceEdgeTestController < ::ApplicationController
  include ::Authentication::User
  include ::Preference::Edge

  attr_accessor :payload_preferences, :payload_public_id

  def initialize(*)
    super
    @payload_preferences = nil
    @payload_public_id = nil
  end

  def preference_payload_preferences
    payload_preferences
  end

  def preference_payload_public_id
    payload_public_id
  end

  def controller_path
    "apex/app/preferences"
  end

  def test_resolved_preference_data
    send(:resolved_preference_data)
  end

  def test_load_preferences_from_record
    send(:load_preferences_from_record)
  end

  def test_preferences_from_record(preference, prefix)
    send(:preferences_from_record, preference, prefix)
  end

  def test_preference_response(preferences, public_id)
    send(:preference_response, preferences, public_id)
  end
end

class PreferenceEdgeTest < ActiveSupport::TestCase
  setup do
    @controller = PreferenceEdgeTestController.new
  end

  test "resolved_preference_data prefers payload values when present" do
    @controller.payload_preferences = { "ct" => "dr", "lx" => "en" }
    @controller.payload_public_id = "pref_payload"

    assert_equal(
      { preferences: { "ct" => "dr", "lx" => "en" }, public_id: "pref_payload" },
      @controller.test_resolved_preference_data,
    )
  end

  test "load_preferences_from_record raises when preferences are missing" do
    assert_raises(PreferenceOperationError) do
      @controller.test_load_preferences_from_record
    end
  end

  test "preferences_from_record and response apply defaults" do
    option = Struct.new(:name)
    association = Struct.new(:option)
    preference =
      Struct.new(
        :app_preference_colortheme, :app_preference_language, :app_preference_timezone,
        :app_preference_region,
      ).new(
        association.new(option.new("dark")),
        association.new(option.new("EN")),
        association.new(option.new("Etc/UTC")),
        association.new(option.new("US")),
      )

    preferences = @controller.test_preferences_from_record(preference, "app")

    assert_equal({ "lx" => "en", "ct" => "dr", "ri" => "us", "tz" => "Etc/UTC" }, preferences)

    response = @controller.test_preference_response({}, "pref_default")

    assert_equal "pref_default", response[:preference][:public_id]
    assert_equal "ja", response[:preference][:lx]
    assert_equal "sy", response[:preference][:ct]
    assert_equal "jp", response[:preference][:ri]
    assert_equal "Asia/Tokyo", response[:preference][:tz]
  end
end
