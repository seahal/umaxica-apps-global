# typed: false
# frozen_string_literal: true

require "test_helper"

class InfoRouteContractTest < ActionDispatch::IntegrationTest
  INFO_APP_HOST = ENV.fetch("INFO_SERVICE_URL")
  INFO_COM_HOST = ENV.fetch("INFO_CORPORATE_URL")
  INFO_ORG_HOST = ENV.fetch("INFO_STAFF_URL")

  test "info internal origin and cloudflared public hosts route to matching surfaces" do
    {
      "info.app.localhost" => "info/app/roots",
      "info.com.localhost" => "info/com/roots",
      "info.org.localhost" => "info/org/roots",
      "info.umaxica.app" => "info/app/roots",
      "info.umaxica.com" => "info/com/roots",
      "info.umaxica.org" => "info/org/roots",
    }.each do |host, controller|
      recognized = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  end

  test "info app route contract" do
    assert_info_surface_routes(INFO_APP_HOST, "info/app")
  end

  test "info com route contract" do
    assert_info_surface_routes(INFO_COM_HOST, "info/com")
  end

  test "info org route contract" do
    assert_info_surface_routes(INFO_ORG_HOST, "info/org")
  end

  private

  def assert_info_surface_routes(host, controller_prefix)
    {
      "/" => ["#{controller_prefix}/roots", "index", :get],
      "/health" => ["#{controller_prefix}/healths", "show", :get],
      "/health/liveness" => ["#{controller_prefix}/health/livenesses", "show", :get],
      "/health/readiness" => ["#{controller_prefix}/health/readinesses", "show", :get],
      "/health/startup" => ["#{controller_prefix}/health/startups", "show", :get],
      "/csp-violation-report" => ["#{controller_prefix}/csp_violation_reports", "create", :post],
      "/api/v0/entries" => ["#{controller_prefix}/api/v0/entries", "index", :get],
      "/api/v0/entries/terms" => ["#{controller_prefix}/api/v0/entries", "show", :get],
      "/api/v0/entries/privacy" => ["#{controller_prefix}/api/v0/entries", "show", :get],
    }.each do |path, (controller, action, method)|
      recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)

      assert_equal controller, recognized[:controller]
      assert_equal action, recognized[:action]
    end
  end
end
