# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  end

  test "GET /health returns an html snapshot" do
    get sign_app_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "sign app"
  end

  test "GET /health/ready returns json" do
    get "/health/ready?ri=jp", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "ready", response.parsed_body["probe"]
  end
end
