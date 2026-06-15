# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRouteNamingTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"),
    com: ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
    org: ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
  }.freeze

  test "robots sitemap csp and token refresh use the current core vocabulary" do
    SURFACES.each do |surface, host|
      assert_respond_to self, :"core_#{surface}_well_known_jwks_path"
      assert_equal "/.well-known/jwks.json", public_send(:"core_#{surface}_well_known_jwks_path")

      assert_respond_to self, :"core_#{surface}_robots_path"
      assert_equal "/robots.txt", public_send(:"core_#{surface}_robots_path")

      assert_respond_to self, :"core_#{surface}_sitemap_path"
      assert_equal "/sitemap.xml", public_send(:"core_#{surface}_sitemap_path")

      assert_respond_to self, :"core_#{surface}_csp_violation_report_path"
      assert_equal "/csp-violation-report", public_send(:"core_#{surface}_csp_violation_report_path")

      assert_recognizes_core_route(host, "/robots.txt", :get, "core/#{surface}/robots", "index")
      assert_recognizes_core_route(host, "/.well-known/jwks.json", :get, "core/#{surface}/well_known/jwks", "show")
      assert_recognizes_core_route(host, "/sitemap.xml", :get, "core/#{surface}/sitemaps", "show")
      assert_recognizes_core_route(
        host,
        "/csp-violation-report",
        :post,
        "core/#{surface}/csp_violation_reports",
        "create",
      )
      assert_recognizes_core_route(
        host,
        "/api/v0/token/refresh",
        :post,
        "core/#{surface}/api/v0/token/refreshes",
        "create",
      )
      assert_recognizes_core_route(
        host,
        "/oidc/backchannel/logout",
        :post,
        "core/#{surface}/oidc/backchannel/logouts",
        "create",
      )

      assert_unrecognized(host, "/oidc/backchannel_logout", :post)
      assert_unrecognized(host, "/accounts", :get)
    end
  end

  private

  def assert_recognizes_core_route(host, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

    assert_equal controller_name, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(host, path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
    end
  end
end
