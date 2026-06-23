# typed: false
# frozen_string_literal: true

require "test_helper"

class ObservabilitySpanScrubberTest < ActiveSupport::TestCase
  class MutableSpan
    attr_accessor :attributes

    def initialize(attributes)
      @attributes = attributes
    end
  end

  class ImmutableSpan
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes
      @attributes_instance_variable = attributes
    end
  end

  test "scrub returns the span unchanged when attributes are not a hash" do
    span = MutableSpan.new(nil)

    assert_same span, ObservabilitySpanScrubber.scrub(span)
  end

  test "scrub mutates spans that expose an attributes writer" do
    span = MutableSpan.new("authorization" => "secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["authorization"]
  end

  test "scrub falls back to instance_variable_set for immutable spans" do
    span = ImmutableSpan.new("authorization" => "secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.instance_variable_get(:@attributes)["authorization"]
  end

  test "scrub_attribute leaves non-scrubbable values unchanged" do
    integer_value = 42

    assert_equal integer_value, ObservabilitySpanScrubber.scrub_attribute("foo", integer_value)
  end

  test "scrub_attribute scrubs nested sensitive values under a non-sensitive key" do
    span = MutableSpan.new("details" => "https://example.com/path?jwt=secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal "https://example.com/path", span.attributes["details"]
  end

  test "scrub_attribute scrubs Hash and Array values under a non-sensitive key" do
    span = MutableSpan.new(
      "payload" => { "token" => "secret" },
      "entries" => ["https://example.com/x?code=abc"],
    )

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["payload"]["token"]
    assert_equal "https://example.com/x", span.attributes["entries"].first
  end
end
