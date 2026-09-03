# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns a plain text snapshot" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    get auth_org_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body
  end
end
