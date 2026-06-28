# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleIntentWriterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @policy = ChronicleRetentionPolicy.create!(
      code: "security",
      name: "Security",
      duration_days: 365,
      permanent: false,
    )
  end

  test "skips visibility contexts that resolve to blank" do
    fallback_called = false

    ChronicleFallbackRecorder.stub(:call, ->(*) { fallback_called = true }) do
      ChronicleIntentWriter.call(
        event_uuid: SecureRandom.uuid,
        action: "auth.sign_in.failed",
        visibility_contexts: ["unknown-context"],
      )
    end

    assert fallback_called
  end

  test "creates chronicle visibility for resolved context" do
    context = ChronicleVisibilityContext.create!(code: "audit", name: "Audit")

    chronicle = ChronicleIntentWriter.call(
      event_uuid: SecureRandom.uuid,
      action: "auth.sign_in.failed",
      visibility_contexts: ["audit"],
    )

    assert_equal [context], chronicle.chronicle_visibility_contexts
  end
end
