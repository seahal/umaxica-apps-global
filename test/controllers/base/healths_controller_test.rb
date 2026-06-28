# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseHealthsControllerTest < ActionDispatch::IntegrationTest
  test "network host GET /health returns OK response without redirect" do
    host! ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost")

    get base_network_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "network host health probes return OK without redirect" do
    host! ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost")

    get base_network_health_liveness_url, headers: browser_headers

    assert_probe_response("liveness")

    get base_network_health_readiness_url, headers: browser_headers

    assert_probe_response("readiness")

    get base_network_health_startup_url, headers: browser_headers

    assert_probe_response("startup")
  end

  test "developer host GET /health returns OK response without redirect" do
    host! ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost")

    get base_developer_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "developer host health probes return OK without redirect" do
    host! ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost")

    get base_developer_health_liveness_url, headers: browser_headers

    assert_probe_response("liveness")

    get base_developer_health_readiness_url, headers: browser_headers

    assert_probe_response("readiness")

    get base_developer_health_startup_url, headers: browser_headers

    assert_probe_response("startup")
  end

  private

  def assert_health_response
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "Generated at"
  end

  def assert_probe_response(check)
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "application/json", response.media_type
    assert_equal check, response.parsed_body["check"]
  end
end
