# typed: false
# frozen_string_literal: true

require "test_helper"

class TurnstileDegradationTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(enabled)
      @enabled = enabled
    end

    def enabled?(_feature)
      @enabled
    end
  end

  test "an upstream outage passes while degraded mode is on" do
    result = apply({ "success" => false, "error" => "timeout", "unavailable" => true }, degraded: true)

    assert result["success"]
    assert result["degraded"]
  end

  test "an upstream outage still fails while degraded mode is off" do
    result = apply({ "success" => false, "error" => "timeout", "unavailable" => true }, degraded: false)

    assert_not result["success"]
    assert_not result["degraded"]
  end

  test "a failed challenge is not degraded" do
    result = apply({ "success" => false, "error" => "invalid-input-response", "unavailable" => false }, degraded: true)

    assert_not result["success"]
  end

  test "a missing secret is configuration and is not degraded" do
    result = apply(
      { "success" => false, "error" => "missing turnstile secret", "unavailable" => false },
      degraded: true,
    )

    assert_not result["success"]
  end

  test "a successful verification is returned untouched" do
    result = apply({ "success" => true, "hostname" => "umaxica.app" }, degraded: true)

    assert result["success"]
    assert_nil result["degraded"]
  end

  private

  def apply(result, degraded:)
    TurnstileDegradation.new(flipper: StubFlipper.new(degraded)).apply(result)
  end
end
