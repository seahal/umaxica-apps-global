# frozen_string_literal: true

require "test_helper"

class OpenTelemetryInitializerTest < ActiveSupport::TestCase
  test "uses explicit instrumentation list instead of use_all and scrubs spans" do
    source = Rails.root.join("config/initializers/opentelemetry.rb").read

    assert_no_match(/c\.use_all/, source)
    assert_includes source, 'c.use("OpenTelemetry::Instrumentation::Rack")'
    assert_includes source, 'c.use("OpenTelemetry::Instrumentation::ActiveRecord")'
    assert_includes source, "ObservabilitySpanScrubber"
  end

  test "scrubs sensitive span attributes" do
    span = Struct.new(:attributes).new(
      {
        "http.url" => "https://example.com/path?token=secret",
        "http.request.header.authorization" => "Bearer secret",
        "http.response.header.set-cookie" => "session=secret",
        "custom" => { cookie: "secret" },
      },
    )

    span = ObservabilitySpanScrubber.scrub(span)

    assert_equal "[FILTERED]", span.attributes["http.url"]
    assert_equal "[FILTERED]", span.attributes["http.request.header.authorization"]
    assert_equal "[FILTERED]", span.attributes["http.response.header.set-cookie"]
    assert_equal "[FILTERED]", span.attributes["custom"][:cookie]
  end
end
