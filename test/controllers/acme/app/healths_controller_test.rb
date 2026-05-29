# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns OK response without redirect" do
    host! ENV["ACME_SERVICE_URL"] || "www.app.localhost"

    get acme_app_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "status=OK"
    assert_includes response.body, "service=acme"
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, response.body)
  end
end
