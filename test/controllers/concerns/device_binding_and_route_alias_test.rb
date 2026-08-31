# typed: false
# frozen_string_literal: true

require "test_helper"

# Two small per-surface translations that every surface relies on: the column a
# device session hangs off, and the alias that lets a Base preference view keep
# naming the auth-side route helper.
class DeviceBindingAndRouteAliasTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class DeviceBindingHarness
    include AuthenticationDeviceBinding

    attr_accessor :resource_type_value, :device_session_class_value

    def resource_type = resource_type_value

    def device_session_class = device_session_class_value

    def invoke(name, ...) = send(name, ...)
  end

  class FakeDeviceSession
    class << self
      attr_reader :created_with

      def create!(attributes)
        @created_with = attributes
        new
      end
    end
  end

  class FakeToken
    attr_accessor :device_session

    attr_reader :updated_with

    def initialize
      @device_session = nil
    end

    def refresh_token_family_id = "family-1"

    def update!(attributes)
      @updated_with = attributes
      @device_session = attributes[:device_session]
    end
  end

  test "device_session_actor_key names the column the surface hangs a session off" do
    harness = DeviceBindingHarness.new

    harness.resource_type_value = "operator"

    assert_equal :staff_id, harness.invoke(:device_session_actor_key)

    harness.resource_type_value = "visitor"

    assert_equal :visitor_id, harness.invoke(:device_session_actor_key)

    harness.resource_type_value = "client"

    assert_equal :user_id, harness.invoke(:device_session_actor_key)
  end

  test "ensure_device_session_for! creates one bound to the actor and the refresh family" do
    harness = DeviceBindingHarness.new
    harness.resource_type_value = "visitor"
    harness.device_session_class_value = FakeDeviceSession
    token = FakeToken.new
    resource = Struct.new(:id).new(31)

    session = harness.invoke(:ensure_device_session_for!, resource, token, dpop_jkt: "jkt-1")

    assert_predicate session, :present?
    assert_equal "jkt-1", FakeDeviceSession.created_with.fetch(:dpop_jkt)
    assert_equal "family-1", FakeDeviceSession.created_with.fetch(:refresh_token_family_id)
    assert_equal 31, FakeDeviceSession.created_with.fetch(:visitor_id)
    assert_equal session, token.device_session
  end

  test "ensure_device_session_for! keeps the session the token already has" do
    harness = DeviceBindingHarness.new
    harness.resource_type_value = "client"
    harness.device_session_class_value = FakeDeviceSession
    token = FakeToken.new
    token.device_session = :existing

    assert_equal :existing, harness.invoke(:ensure_device_session_for!, Struct.new(:id).new(1), token)
  end

  test "a Base preference view may name the auth-side route helper" do
    harness = Class.new do
      include BasePreferenceViewRouteAliases

      attr_reader :called

      def base_app_preference_url(*args) = "base-app-preference-url:#{args.inspect}"

      def invoke(name, ...) = send(name, ...)
    end.new

    assert_equal "base-app-preference-url:[]", harness.invoke(:auth_app_preference_url)
    assert_respond_to harness, :auth_app_preference_url

    assert_raises(NoMethodError) { harness.invoke(:auth_app_something_else_url) }
  end
end
