# typed: false
# frozen_string_literal: true

require "test_helper"

# Forgery protection contract for the MCP endpoint.
#
# The MCP endpoint keeps the same `protect_from_forgery` declaration every bare endpoint carries;
# nothing is skipped or weakened for it. Two properties have to hold together, and they are easy to
# break in opposite directions, so both are asserted here:
#
#   * a non-browser MCP client, which sends neither a session cookie nor Fetch Metadata headers,
#     can reach the endpoint;
#   * a browser-shaped request from a foreign origin still cannot.
#
# The test environment disables forgery protection globally (config/environments/test.rb), which
# makes `verified_request?` short-circuit. These tests enable it explicitly so the request takes the
# same path it takes in production; without that, both assertions would pass vacuously.
class McpForgeryProtectionTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = {
    "CONTENT_TYPE" => "application/json",
    "HTTP_ACCEPT" => "application/json, text/event-stream",
  }.freeze

  test "a non-browser MCP client reaches the endpoint with forgery protection enabled" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    # Production serves this endpoint over TLS. The verification path differs for TLS in one of the
    # strategies, so exercise the transport this endpoint actually runs on.
    https!
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"))

    post("/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: JSON_HEADERS)

    assert_response :success
    assert_equal 3, response.parsed_body.dig("result", "tools").size
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "a browser-shaped cross-site request is still rejected with forgery protection enabled" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    https!
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"))

    post(
      "/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: JSON_HEADERS.merge("HTTP_SEC_FETCH_SITE" => "cross-site"),
    )

    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "the MCP controllers keep the application-wide forgery protection strategy" do
    %w(base/app base/com base/org side/app side/com side/org).each do |controller|
      controller_class = "#{controller}/mcps_controller".camelize.constantize

      assert_equal :header_or_legacy_token, controller_class.forgery_protection_verification_strategy
      assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
                   controller_class.forgery_protection_strategy
    end
  end
end
