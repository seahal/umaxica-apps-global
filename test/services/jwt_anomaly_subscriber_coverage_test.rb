# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("app/subscribers/jwt_anomaly_subscriber")

class JwtAnomalySubscriberCoverageTest < ActiveSupport::TestCase
  fixtures :jwt_occurrences

  class MockEvent
    attr_reader :name, :payload, :time

    def initialize(name:, payload:, time: nil)
      @name = name
      @payload = payload
      @time = time
    end
  end

  test "emit creates anomaly event and preserves extra metadata" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: {
        code: "AUTH_USER_MALFORMED_TOKEN",
        request_host: "id.app.localhost",
        kid: "kid-1",
        alg: "ES384",
        typ: "JWT",
        iss: "jit",
        jti: "jti-123",
        error_class: "JWT::DecodeError",
        error_message: "invalid token",
        extra: "kept",
      },
      time: Time.current.change(usec: 0),
    )

    assert_difference "JwtAnomalyEvent.count", 1 do
      JwtAnomalySubscriber.new.emit(mock_event)
    end

    event = JwtAnomalyEvent.order(:id).last

    assert_equal jwt_occurrences(:auth_user_malformed_token), event.jwt_occurrence
    assert_equal({ "extra" => "kept" }, event.metadata)
  end

  test "emit ignores unrelated events and logs creation failures" do
    assert_no_difference "JwtAnomalyEvent.count" do
      JwtAnomalySubscriber.new.emit(MockEvent.new(name: "other.event", payload: { code: "AUTH_USER_MALFORMED_TOKEN" }))
    end

    logged_message = nil
    Rails.logger.stub(:error, ->(message) { logged_message = message }) do
      JwtAnomalyEvent.stub(:create!, ->(**) { raise StandardError, "explode" }) do
        JwtAnomalySubscriber.new.emit(
          MockEvent.new(
            name: "jwt.anomaly.detected",
            payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
          ),
        )
      end
    end

    assert_includes logged_message, "JwtAnomalySubscriber failed"
  end

  test "build_metadata includes extra fields" do
    subscriber = JwtAnomalySubscriber.new
    payload = {
      code: "TEST_CODE",
      request_host: "host",
      kid: "kid",
      alg: "alg",
      typ: "typ",
      iss: "iss",
      jti: "jti",
      error_class: "Error",
      error_message: "msg",
      extra_field1: "extra1",
      extra_field2: "extra2",
    }

    metadata = subscriber.send(:build_metadata, payload)

    assert_equal({ extra_field1: "extra1", extra_field2: "extra2" }, metadata)
  end
end
