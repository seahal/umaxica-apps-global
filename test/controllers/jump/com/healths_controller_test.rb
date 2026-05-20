# typed: false
# frozen_string_literal: true

require "test_helper"

class Jump::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns OK response without redirect" do
    host! ENV["JUMP_CORPORATE_URL"] || "jump.com.localhost"

    get jump_com_health_url, headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "OK"
  end
end
