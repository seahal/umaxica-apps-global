# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns an html snapshot without redirect" do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

    get base_com_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "com"
  end
end
