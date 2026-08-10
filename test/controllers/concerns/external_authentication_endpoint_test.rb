# typed: false
# frozen_string_literal: true

require "test_helper"

# The availability gate fails closed when the Flipper store is unreadable. These tests pin the
# diagnostic that goes with it: a store failure previously surfaced only as a generic provider
# error, which is indistinguishable from an outage at the provider.
class ExternalAuthenticationEndpointTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Endpoint
    include ExternalAuthenticationEndpoint

    def start_available?(**)
      external_authentication_start_available?(**)
    end

    def callback_available?(**)
      external_authentication_callback_available?(**)
    end
  end

  setup do
    @endpoint = Endpoint.new
  end

  test "callback availability is false and names the feature when the flag store is unreadable" do
    logged =
      capture_availability_logs do
        with_unreadable_flag_store do
          assert_not @endpoint.callback_available?(provider: "google", ceremony: { state: "x" }, context: {})
        end
      end

    assert_equal 1, logged.size
    assert_includes logged.first, "external_authentication.availability.misconfigured"
    assert_includes logged.first, "social_ceremony_app_google"
    assert_includes logged.first, "callback"
  end

  test "start availability is false and names the feature when the flag store is unreadable" do
    logged =
      capture_availability_logs do
        with_unreadable_flag_store do
          assert_not @endpoint.start_available?(provider: "google", operation: "login", context: {})
        end
      end

    assert_equal 1, logged.size
    assert_includes logged.first, "social_ceremony_app_google"
    assert_includes logged.first, "start"
  end

  test "start availability is false without a log when the provider is switched off" do
    logged =
      capture_availability_logs do
        with_feature_disabled(:social_ceremony_app_google) do
          assert_not @endpoint.start_available?(provider: "google", operation: "login", context: {})
        end
      end

    assert_empty logged
  end

  test "an issued callback still drains after the provider is switched off" do
    with_feature_disabled(:social_ceremony_app_google) do
      assert @endpoint.callback_available?(provider: "google", ceremony: { state: "x" }, context: {})
    end
  end

  test "callback availability is true and logs nothing when the feature is enabled" do
    logged =
      capture_availability_logs do
        assert @endpoint.callback_available?(provider: "google", ceremony: { state: "x" }, context: {})
      end

    assert_empty logged
  end

  private

  def capture_availability_logs
    messages = []
    original = Rails.logger
    Rails.logger =
      ActiveSupport::Logger.new(StringIO.new).tap do |logger|
        logger.define_singleton_method(:error) { |message = nil, &block| messages << (message || block&.call).to_s }
      end
    yield
    messages
  ensure
    Rails.logger = original
  end

  def with_feature_disabled(feature)
    Flipper.disable(feature)
    yield
  ensure
    Flipper.enable(feature)
  end

  def with_unreadable_flag_store
    Flipper.define_singleton_method(:enabled?) { |*| raise Redis::CannotConnectError, "flag store down" }
    yield
  ensure
    Flipper.singleton_class.remove_method(:enabled?)
  end
end
