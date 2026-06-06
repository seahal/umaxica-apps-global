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
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "Generated at"
  end
end
