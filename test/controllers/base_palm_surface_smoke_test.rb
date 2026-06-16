# typed: false
# frozen_string_literal: true

require "test_helper"

class BasePalmSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "base app public endpoints respond on the control-plane surface" do
    host = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
    host! host

    get "/", headers: { "Host" => host }

    assert_response :success

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/robots.txt", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    get "/sitemap.xml", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    post "/csp-violation-report", headers: { "Host" => host }

    assert_response :success
  end

  test "palm app public endpoints and bearer profile api respond on the native surface" do
    host = ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")
    host! host

    get "/", headers: { "Host" => host }

    assert_response :success

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/api/v0/profile", headers: json_headers

    assert_response :unauthorized
    assert_equal "authentication_required", response.parsed_body.dig("error", "code")
  end

  private

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }
  end
end
