# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeHealthsControllerTest < ActionDispatch::IntegrationTest
  test "network host GET /health returns OK response without redirect" do
    host! ENV["ACME_NETWORK_URL"]

    get acme_network_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "developer host GET /health returns OK response without redirect" do
    host! ENV["ACME_DEVELOPER_URL"]

    get acme_developer_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  private

  def assert_health_response
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "status=OK"
    assert_includes response.body, "service=acme"
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, response.body)
  end
end
