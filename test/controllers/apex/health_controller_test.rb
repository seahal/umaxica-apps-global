# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::HealthControllerTest < ActionDispatch::IntegrationTest
  test "network host GET /health returns OK response without redirect" do
    host! ENV["APEX_NETWORK_URL"]

    get apex_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "developer host GET /health returns OK response without redirect" do
    host! ENV["APEX_DEVELOPER_URL"]

    get "/health", headers: browser_headers

    assert_response :success

    assert_health_response
  end

  private

  def assert_health_response
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "OK"
  end
end
