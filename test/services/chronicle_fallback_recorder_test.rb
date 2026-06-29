# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class ChronicleFallbackRecorderTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "call logs a formatted error event" do
    logged = nil

    Rails.logger.stub(:error, ->(message) { logged = message }) do
      ChronicleFallbackRecorder.call(
        event: "chronicle.intent_write_failed",
        event_uuid: "evt-123",
        request_id: "req-456",
        action: "test.action",
        actor: nil,
        subject: nil,
        error: StandardError.new("boom"),
        manual_recovery_required: true,
      )
    end

    assert_match(/chronicle\.fallback_record/, logged)
    assert_match(/evt-123/, logged)
    assert_match(/boom/, logged)
  end

  test "call tolerates nil error" do
    logged = nil

    Rails.logger.stub(:error, ->(message) { logged = message }) do
      ChronicleFallbackRecorder.call(
        event: "chronicle.guarantee_failed",
        event_uuid: "evt-789",
        request_id: "req-000",
        action: "test.action",
      )
    end

    assert_match(/chronicle\.fallback_record/, logged)
    assert_match(/evt-789/, logged)
  end
end
