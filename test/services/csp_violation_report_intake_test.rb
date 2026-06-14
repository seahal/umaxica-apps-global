# frozen_string_literal: true

require "test_helper"

class CspViolationReportIntakeTest < ActiveSupport::TestCase
  test "sanitizes legacy report urls and strips samples" do
    logged = []
    logger = capturing_logger(logged)

    result = CspViolationReportIntake.call(
      raw_body: {
        "csp-report" => {
          "document-uri" => "https://app.example.test/path?token=secret#frag",
          "blocked-uri" => "https://cdn.example.test/app.js?secret=value#frag",
          "effective-directive" => "script-src",
          "line-number" => "12",
          "script-sample" => "private inline code",
        },
      }.to_json,
      host: "app.example.test",
      user_agent: "ExampleBrowser/1.0 details",
      logger: logger,
    )

    assert_equal :accepted, result.status
    assert_equal 1, result.reports_count

    data = JSON.parse(logged.fetch(0), symbolize_names: true).fetch(:data)
    assert_equal "https://app.example.test/path", data.fetch(:document_uri)
    assert_equal "https://cdn.example.test/app.js", data.fetch(:blocked_uri)
    assert_equal "script-src", data.fetch(:effective_directive)
    assert_equal 12, data.fetch(:line_number)
    assert_equal "application", data.fetch(:category)
    assert_equal "application:script-src:https://cdn.example.test", data.fetch(:aggregation_key)
    assert_equal "ExampleBrowser/1.0", data.fetch(:user_agent_family)
    assert_nil data[:script_sample]
  end

  test "classifies reporting api browser extension noise" do
    logged = []

    result = CspViolationReportIntake.call(
      raw_body: [
        {
          "type" => "csp-violation",
          "body" => {
            "blocked-uri" => "chrome-extension://abc/script.js",
            "effective-directive" => "script-src",
          },
        },
      ].to_json,
      host: "app.example.test",
      logger: capturing_logger(logged),
    )

    assert_equal :accepted, result.status
    assert_equal 1, result.reports_count

    data = JSON.parse(logged.fetch(0), symbolize_names: true).fetch(:data)
    assert_equal "browser_extension", data.fetch(:category)
    assert_equal "browser_extension:script-src:chrome-extension", data.fetch(:aggregation_key)
  end

  test "malformed and oversized bodies are accepted without logging" do
    malformed_logged = []
    malformed = CspViolationReportIntake.call(
      raw_body: "{not json",
      host: "app.example.test",
      logger: capturing_logger(malformed_logged),
    )

    oversized_logged = []
    oversized = CspViolationReportIntake.call(
      raw_body: "x" * (CspViolationReportIntake::MAX_BODY_BYTES + 1),
      host: "app.example.test",
      logger: capturing_logger(oversized_logged),
    )

    assert_equal :malformed, malformed.status
    assert_equal :too_large, oversized.status
    assert_empty malformed_logged
    assert_empty oversized_logged
  end

  private

  def capturing_logger(messages)
    Class.new do
      define_method(:info) { |message| messages << message }
    end.new
  end
end
