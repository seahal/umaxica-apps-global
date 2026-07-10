# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CspViolationReportIntakeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  EXPECTED_SCHEMA_KEYS = %i(
    surface
    host
    category
    disposition
    document_uri
    blocked_uri
    source_file
    effective_directive
    violated_directive
    original_policy
    status_code
    line_number
    column_number
    aggregation_key
    user_agent_family
  ).freeze

  test "valid legacy nested report emits Rails event with scrubbed fixed schema payload" do
    result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "csp-report" => {
              "document-uri" => "https://app.example.test/path?token=secret#frag",
              "blocked-uri" => "https://cdn.example.test/app.js?secret=value#frag",
              "source-file" => "https://app.example.test/application.js?cookie=secret#frag",
              "effective-directive" => "script-src",
              "violated-directive" => "script-src-elem",
              "original-policy" => "default-src 'self'",
              "disposition" => "enforce",
              "line-number" => "12",
              "column-number" => "9",
              "status-code" => "200",
              "script-sample" => "private inline code",
              "unknown" => "private",
            },
          }.to_json,
          host: "app.example.test",
          user_agent: "ExampleBrowser/1.0 details",
        )
      end

    assert_equal :accepted, result.status
    assert_equal 1, result.reports_count

    name, payload = events.fetch(0)

    assert_equal CspViolationReportIntake::EVENT_NAME, name
    assert_equal EXPECTED_SCHEMA_KEYS, payload.keys
    assert_equal "https://app.example.test/path", payload.fetch(:document_uri)
    assert_equal "https://cdn.example.test/app.js", payload.fetch(:blocked_uri)
    assert_equal "https://app.example.test/application.js", payload.fetch(:source_file)
    assert_equal "script-src", payload.fetch(:effective_directive)
    assert_equal "script-src-elem", payload.fetch(:violated_directive)
    assert_equal "default-src 'self'", payload.fetch(:original_policy)
    assert_equal "enforce", payload.fetch(:disposition)
    assert_equal 12, payload.fetch(:line_number)
    assert_equal 9, payload.fetch(:column_number)
    assert_equal 200, payload.fetch(:status_code)
    assert_equal "application", payload.fetch(:category)
    assert_equal "application:script-src:https://cdn.example.test", payload.fetch(:aggregation_key)
    assert_equal "app", payload.fetch(:surface)
    assert_equal "app.example.test", payload.fetch(:host)
    assert_equal "ExampleBrowser/1.0", payload.fetch(:user_agent_family)
    assert_not_includes payload.keys, :script_sample
    assert_not_includes payload.keys, :unknown
    assert_not_includes payload.values, "private inline code"
  end

  test "valid reporting api flat and array payloads emit the same event" do
    flat_result, flat_events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "blocked-uri" => "https://cdn.example.test/app.js",
            "effective-directive" => "script-src",
          }.to_json,
          host: "com.example.test",
        )
      end

    array_result, array_events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: [
            {
              "type" => "csp-violation",
              "body" => {
                "blocked-uri" => "chrome-extension://abc/script.js",
                "effective-directive" => "script-src",
              },
            },
          ].to_json,
          host: "org.example.test",
        )
      end

    assert_equal :accepted, flat_result.status
    assert_equal CspViolationReportIntake::EVENT_NAME, flat_events.fetch(0).fetch(0)
    assert_equal "application", flat_events.fetch(0).fetch(1).fetch(:category)
    assert_equal "com", flat_events.fetch(0).fetch(1).fetch(:surface)

    assert_equal :accepted, array_result.status
    assert_equal CspViolationReportIntake::EVENT_NAME, array_events.fetch(0).fetch(0)
    assert_equal "browser_extension", array_events.fetch(0).fetch(1).fetch(:category)
    assert_equal "org", array_events.fetch(0).fetch(1).fetch(:surface)
  end

  test "malformed empty and unexpected json shapes do not raise and emit nothing" do
    bodies = ["{not json", "", "null", "42", "\"simple string\"", "[]", "[1,2,3]"]

    bodies.each do |body|
      result, events =
        capture_events do
          CspViolationReportIntake.call(raw_body: body, host: "app.example.test")
        end

      assert_includes %i(malformed accepted), result.status
      assert_empty events
    end
  end

  test "invalid utf8 bytes do not raise and are sanitized" do
    raw_body = +"{\"csp-report\":{\"document-uri\":\"https://app.example.test/\xC3(\",\"effective-directive\":\"script-src\"}}"
    raw_body.force_encoding(Encoding::ASCII_8BIT)

    result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: raw_body,
          host: "app.example.test",
        )
      end

    assert_equal :accepted, result.status
    assert_equal "https://app.example.test/(", events.fetch(0).fetch(1).fetch(:document_uri)
  end

  test "long fields are truncated at max string length" do
    long_value = "a" * (CspViolationReportIntake::MAX_STRING_LENGTH + 20)

    _result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "csp-report" => {
              "effective-directive" => long_value,
            },
          }.to_json,
          host: "app.example.test",
        )
      end

    assert_equal CspViolationReportIntake::MAX_STRING_LENGTH,
                 events.fetch(0).fetch(1).fetch(:effective_directive).length
  end

  test "oversized body returns too large and emits nothing" do
    result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: "x" * (CspViolationReportIntake::MAX_BODY_BYTES + 1),
          host: "app.example.test",
        )
      end

    assert_equal :too_large, result.status
    assert_equal 0, result.reports_count
    assert_empty events
  end

  test "raw payload and script sample are not emitted" do
    _result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "csp-report" => {
              "blocked-uri" => "https://cdn.example.test/app.js?authorization=secret#token",
              "effective-directive" => "script-src",
              "script-sample" => "alert(document.cookie)",
            },
          }.to_json,
          host: "app.example.test",
        )
      end

    payload = events.fetch(0).fetch(1)

    assert_equal "https://cdn.example.test/app.js", payload.fetch(:blocked_uri)
    assert_not_includes payload.keys, :raw_body
    assert_not_includes payload.keys, :script_sample
    assert_not_includes payload.values, "alert(document.cookie)"
  end

  test "surface is derived for app com org net and dev hosts" do
    {
      "www.app.localhost" => "app",
      "www.com.localhost" => "com",
      "www.org.localhost" => "org",
      "www.net.localhost" => "net",
      "www.dev.localhost" => "dev",
    }.each do |host, surface|
      _result, events =
        capture_events do
          CspViolationReportIntake.call(
            raw_body: { "csp-report" => { "effective-directive" => "script-src" } }.to_json,
            host: host,
          )
        end

      assert_equal surface, events.fetch(0).fetch(1).fetch(:surface)
    end
  end

  test "invalid uri in blocked-uri falls back to string splitting and invalid origin" do
    _result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "csp-report" => {
              "blocked-uri" => "http://[",
              "effective-directive" => "script-src",
            },
          }.to_json,
          host: "app.example.test",
        )
      end

    payload = events.fetch(0).fetch(1)

    assert_equal "http://[", payload.fetch(:blocked_uri)
    assert_equal "application", payload.fetch(:category)
    assert_equal "application:script-src:invalid", payload.fetch(:aggregation_key)
  end

  test "invalid uri that starts with extension scheme prefix is classified as browser extension" do
    _result, events =
      capture_events do
        CspViolationReportIntake.call(
          raw_body: {
            "csp-report" => {
              "blocked-uri" => "chrome-extension://[invalid",
              "effective-directive" => "script-src",
            },
          }.to_json,
          host: "app.example.test",
        )
      end

    payload = events.fetch(0).fetch(1)

    assert_equal "browser_extension", payload.fetch(:category)
  end

  private

  def capture_events
    events = []
    result = nil

    Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
      result = yield
    end

    [result, events]
  end
end
