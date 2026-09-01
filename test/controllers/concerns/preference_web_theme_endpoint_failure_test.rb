# typed: false
# frozen_string_literal: true

require "test_helper"

# A theme write that fails part-way must not be swallowed: the endpoint records
# the failure class and re-raises so the request ends as an error rather than as
# a success that stored nothing. The class alone is recorded -- the exception
# message can carry the token material the write was working on.
class PreferenceWebThemeEndpointFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include PreferenceWebThemeEndpoint

    attr_accessor :requested

    def requested_theme_value = requested

    def ensure_preference_access_token_audience_for_write! = nil

    def persist_theme!(_value) = raise(IOError, "preference store unavailable")

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a request that names no theme is a no-op" do
    @harness.requested = nil

    assert_nil @harness.invoke(:apply_theme_update_from_request!)
  end

  test "a failed theme write is recorded by class and re-raised rather than reported as success" do
    @harness.requested = "dark"
    recorded = []

    Rails.logger.stub(:error, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      assert_raises(IOError) { @harness.invoke(:apply_theme_update_from_request!) }
    end

    assert(recorded.any? { |line| line.include?("theme update failed: IOError") })
    assert(recorded.none? { |line| line.include?("preference store unavailable") })
  end
end
