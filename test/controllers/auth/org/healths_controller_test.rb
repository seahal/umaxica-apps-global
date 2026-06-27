# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns an html snapshot" do
    host! ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

    get auth_org_health_url(ri: "jp")

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "sign org"
  end
end
