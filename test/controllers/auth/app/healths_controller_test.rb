# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("AUTH_SERVICE_URL")
  end

  test "GET /health returns an html snapshot" do
    get auth_app_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
  end

  test "GET /health/readiness returns json" do
    get "/health/readiness?ri=jp", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "readiness", response.parsed_body["check"]
  end
end
