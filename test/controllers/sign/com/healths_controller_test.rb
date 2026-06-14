# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns an html snapshot without redirect" do
    host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")

    get sign_com_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "sign com"
  end
end
