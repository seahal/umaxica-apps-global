# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JwtAnomalySubscriberTest < ActiveSupport::TestCase
  fixtures :jwt_occurrences

  class MockEvent
    attr_reader :name, :payload, :time

    def initialize(name:, payload:, time: nil)
      @name = name
      @payload = payload
      @time = time
    end
  end

  test "emit does nothing when event name does not match" do
    mock_event = MockEvent.new(
      name: "other.event",
      payload: { code: "MALFORMED_TOKEN" },
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "emit does nothing when event does not respond to name" do
    payload = { code: "MALFORMED_TOKEN" }
    subscriber = JwtAnomalySubscriber.new

    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(payload)
    end
  end

  test "emit does nothing when code is blank" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "" },
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "emit handles missing payload gracefully" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: nil,
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  def setup_anomaly_event_test
    occurred_at = Time.current.change(usec: 0)
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
      time: occurred_at,
    )

    subscriber = JwtAnomalySubscriber.new

    assert_difference "JwtAnomalyEvent.count", 1 do
      subscriber.emit(mock_event)
    end

    [JwtAnomalyEvent.order(:id).last, occurred_at]
  end

  test "emit creates anomaly event linked to occurrence" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal jwt_occurrences(:auth_user_malformed_token), event.jwt_occurrence
    assert_equal "AUTH_USER_MALFORMED_TOKEN", event.code
  end

  test "emit stores jwt header fields correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "kid-1", event.kid
    assert_equal "ES384", event.alg
    assert_equal "JWT", event.typ
  end

  test "emit stores jwt claim fields correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "jit", event.issuer
    assert_equal "jti-123", event.jti
  end

  test "emit stores error information correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "JWT::DecodeError", event.error_class
    assert_equal "invalid token", event.error_message
    assert_equal({ "extra" => "kept" }, event.metadata)
  end

  test "emit stores request host and timestamp correctly" do
    event, occurred_at = setup_anomaly_event_test

    assert_equal "id.app.localhost", event.request_host
    assert_equal occurred_at, event.occurred_at
  end

  test "emit does nothing when occurrence is not found" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "UNKNOWN_CODE" },
    )

    subscriber = JwtAnomalySubscriber.new

    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "build_metadata strips known top-level event fields" do
    subscriber = JwtAnomalySubscriber.new

    metadata = subscriber.send(
      :build_metadata,
      {
        :code => "AUTH_USER_MALFORMED_TOKEN",
        "request_host" => "id.app.localhost",
        :kid => "kid-1",
        :alg => "ES384",
        :typ => "JWT",
        :iss => "jit",
        :jti => "jti-123",
        :error_class => "JWT::DecodeError",
        :error_message => "invalid token",
        :extra => "kept",
        "another" => "kept-too",
      },
    )

    assert_equal({ :extra => "kept", "another" => "kept-too" }, metadata)
  end

  test "emit logs and swallows persistence errors from event creation" do
    logged_message = nil
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
    )

    JwtAnomalyEvent.stub(:create!, ->(**) { raise ActiveRecord::ActiveRecordError, "explode" }) do
      Rails.logger.stub(:error, ->(message) { logged_message = message }) do
        JwtAnomalySubscriber.new.emit(mock_event)
      end
    end

    payload = JSON.parse(logged_message)

    assert_equal "jwt.anomaly.subscriber_failed", payload.fetch("event")
    assert_equal "ActiveRecord::ActiveRecordError", payload.dig("data", "error_class")
    assert_equal "explode", payload.dig("data", "message")
  end
end
