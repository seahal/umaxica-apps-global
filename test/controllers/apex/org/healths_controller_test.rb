# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns OK response without redirect" do
    host! ENV["APEX_STAFF_URL"] || "www.org.localhost"

    get apex_org_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "OK"
  end
end
