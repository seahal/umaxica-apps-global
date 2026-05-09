# typed: false
# frozen_string_literal: true

require "test_helper"

class CspViolationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    RateLimit.store.clear
  end

  teardown do
    RateLimit.store.clear
  end

  test "POST /csp-violation-report with valid payload returns 204 and records event" do
    host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")

    payload = {
      "csp-report" => {
        "document-uri" => "https://example.com/page",
        "blocked-uri" => "https://evil.com/script.js",
        "violated-directive" => "script-src",
        "effective-directive" => "script-src",
      },
    }

    recorded_events = []
    mock_record = ->(name, _payload = {}) { recorded_events << { name: name, payload: _payload } }

    Rails.event.stub(:record, mock_record) do
      post "/csp-violation-report",
           params: payload.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :no_content
    assert_equal 1, recorded_events.size
    assert_equal "security.csp_violation", recorded_events.first[:name]
    assert_equal "https://example.com/page", recorded_events.first[:payload][:"document-uri"]
  end

  test "POST /csp-violation-report with malformed payload returns 204 without raising" do
    host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")

    assert_nothing_raised do
      post "/csp-violation-report",
           params: "not-json",
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :no_content
  end

  test "POST /csp-violation-report is rate limited by IP" do
    host!(ENV.fetch("APEX_SERVICE_URL", "www.app.localhost"))

    RateLimit.define_singleton_method(:default_rate_limit) { 1 }

    post(
      "/csp-violation-report",
      params: { "csp-report" => {} }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" },
    )

    assert_response :no_content

    post(
      "/csp-violation-report",
      params: { "csp-report" => {} }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" },
    )

    assert_response :too_many_requests
    assert_equal "default_ip", response.headers["X-RateLimit-Rule"]
  ensure
    RateLimit.define_singleton_method(:default_rate_limit) { 300 }
  end
end
