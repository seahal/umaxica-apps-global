# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns OK response without redirect" do
    host! ENV["ACME_CORPORATE_URL"] || "www.com.localhost"

    get acme_com_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "status=OK"
    assert_includes response.body, "service=acme"
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, response.body)
  end
end
