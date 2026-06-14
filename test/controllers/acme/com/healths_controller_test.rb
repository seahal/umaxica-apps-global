# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::HealthsControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns an html snapshot without redirect" do
    host! ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")

    get acme_com_health_url(ri: "jp"), headers: browser_headers

    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "com"
  end
end
