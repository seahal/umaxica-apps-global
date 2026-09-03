# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "GET /health returns a plain text snapshot" do
    get auth_app_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body
  end

  test "GET /health/readinesses returns plain text" do
    get "/health/readinesses?ri=jp", headers: { "Accept" => "text/html" }

    assert_equal "text/plain", response.media_type
    assert_equal "ok\n", response.body
  end
end
