# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::App::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns an html snapshot without redirect" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    get base_app_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "app"
  end
end
