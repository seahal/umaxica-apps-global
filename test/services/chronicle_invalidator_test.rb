# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ChronicleInvalidatorTest < ActiveSupport::TestCase
  test "call updates chronicle result and records fallback" do
    chronicle_result = nil
    chronicle = Object.new
    chronicle.define_singleton_method(:update!) { |attrs| chronicle_result = attrs[:result] }
    chronicle.define_singleton_method(:result) { chronicle_result }

    event_uuid = "test-uuid"
    request_id = "test-request"
    fallback_called = false

    ChronicleFallbackRecorder.stub(:call, ->(**_kwargs) { fallback_called = true }) do
      result = ChronicleInvalidator.new(
        chronicle: chronicle,
        event_uuid: event_uuid,
        request_id: request_id,
        action: "test.action",
      ).call

      assert_equal "manual_recovery_required", result.result
      assert fallback_called
    end
  end
end
