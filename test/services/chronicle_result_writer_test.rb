# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleResultWriterTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    @policy = ChronicleRetentionPolicy.create!(
      code: "security",
      name: "Security",
      duration_days: 0,
      permanent: true,
    )
    @chronicle = Chronicle.create!(
      event_uuid: SecureRandom.uuid,
      action: "auth.sign_in.failed",
      result: "intent",
      metadata: {},
      changeset: {},
      occurred_at: Time.current,
      chronicle_retention_policy: @policy,
    )
  end

  test "logs fallback and reraises when result update fails" do
    fallback_called = false
    error = StandardError.new("update failed")

    @chronicle.stub(:update!, ->(*) { raise error }) do
      ChronicleFallbackRecorder.stub(:call, ->(*) { fallback_called = true }) do
        assert_raises(StandardError) do
          ChronicleResultWriter.call(
            chronicle: @chronicle,
            result: "succeeded",
            event_uuid: SecureRandom.uuid,
            request_id: "request-result-failure",
            action: "auth.sign_in.failed",
          )
        end
      end
    end

    assert fallback_called
  end
end
