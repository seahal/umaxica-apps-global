# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleCapturableTest < ActiveSupport::TestCase
  fixtures_none!

  class FakeChronicle
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class FakeModel
    include ChronicleCapturable
  end

  setup do
    @chronicle = FakeChronicle.new(1)
  end

  test "capture yields block and returns result" do
    ChronicleIntentWriter.stub(:call, @chronicle) do
      ChronicleResultWriter.stub(:call, nil) do
        result = FakeModel.capture(action: "test.action") { "block_result" }

        assert_equal "block_result", result
      end
    end
  end

  test "capture writes success result when chronicle is present" do
    result_written = false

    ChronicleIntentWriter.stub(:call, @chronicle) do
      ChronicleResultWriter.stub(:call, ->(*) { result_written = true }) do
        FakeModel.capture(action: "test.action") { "ok" }
      end
    end

    assert result_written
  end

  test "capture logs guarantee failure when chronicle intent is nil" do
    guarantee_logged = false

    ChronicleIntentWriter.stub(:call, nil) do
      ChronicleFallbackRecorder.stub(:call, ->(*) { guarantee_logged = true }) do
        FakeModel.capture(action: "test.action") { "ok" }
      end
    end

    assert guarantee_logged
  end

  test "capture writes failure result when block raises" do
    failure_written = false

    assert_raises(StandardError) do
      ChronicleIntentWriter.stub(:call, @chronicle) do
        ChronicleResultWriter.stub(:call, ->(**args) { failure_written = args.fetch(:result) == "failed" }) do
          ChronicleInvalidator.stub(:call, nil) do
            FakeModel.capture(action: "test.action") { raise StandardError, "boom" }
          end
        end
      end
    end

    assert failure_written
  end

  test "capture handles intent write failure with fallback recorder" do
    fallback_called = false

    ChronicleIntentWriter.stub(:call, ->(*) { raise StandardError, "intent failed" }) do
      ChronicleFallbackRecorder.stub(:call, ->(*) { fallback_called = true }) do
        result = FakeModel.capture(action: "test.action") { "block_result" }

        assert_equal "block_result", result
      end
    end

    assert fallback_called
  end

  test "capture handles result write failure with invalidation" do
    invalidation_called = false

    ChronicleIntentWriter.stub(:call, @chronicle) do
      ChronicleResultWriter.stub(:call, ->(*) { raise StandardError, "result failed" }) do
        ChronicleInvalidator.stub(:call, ->(*) { invalidation_called = true }) do
          FakeModel.capture(action: "test.action") { "ok" }
        end
      end
    end

    assert invalidation_called
  end

  test "capture handles invalidation failure with fallback recorder" do
    fallback_calls = []

    ChronicleIntentWriter.stub(:call, @chronicle) do
      ChronicleResultWriter.stub(:call, ->(*) { raise StandardError, "result failed" }) do
        ChronicleInvalidator.stub(:call, ->(*) { raise StandardError, "invalidation failed" }) do
          ChronicleFallbackRecorder.stub(:call, ->(*args) { fallback_calls << args.first }) do
            FakeModel.capture(action: "test.action") { "ok" }
          end
        end
      end
    end

    assert_equal 2, fallback_calls.size
    assert_includes fallback_calls.pluck(:event), "chronicle.invalidation_failed"
    assert_includes fallback_calls.pluck(:event), "chronicle.manual_recovery_required"
  end

  test "capture handles failure result write with invalidation" do
    invalidation_called = false

    assert_raises(StandardError) do
      ChronicleIntentWriter.stub(:call, @chronicle) do
        ChronicleResultWriter.stub(
          :call,
          lambda do |**args|
            raise StandardError, "result failed" if args.fetch(:result) == "failed"
          end,
        ) do
          ChronicleInvalidator.stub(:call, ->(*) { invalidation_called = true }) do
            FakeModel.capture(action: "test.action") { raise StandardError, "boom" }
          end
        end
      end
    end

    assert invalidation_called
  end
end
