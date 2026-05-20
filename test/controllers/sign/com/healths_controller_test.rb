# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns OK response without redirect" do
    host! ENV["ID_CORPORATE_URL"] || "id.com.localhost"

    get sign_com_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "OK"
  end
end
