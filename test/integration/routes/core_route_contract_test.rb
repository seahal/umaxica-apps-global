# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRouteContractTest < ActionDispatch::IntegrationTest
  CORE_APP_HOST = ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app")
  CORE_COM_HOST = ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com")
  CORE_ORG_HOST = ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org")

  test "core app route contract" do
    assert_recognizes_route "https://#{CORE_APP_HOST}/robots.txt", :get,
                            controller: "core/app/robots", action: "index"
    assert_recognizes_route "https://#{CORE_APP_HOST}/sitemap.xml", :get,
                            controller: "core/app/sitemaps", action: "show"
    assert_recognizes_route "https://#{CORE_APP_HOST}/csp-violation-report", :post,
                            controller: "core/app/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{CORE_APP_HOST}/oidc/backchannel/logout", :post,
                            controller: "core/app/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{CORE_APP_HOST}/sso/authorize", :get,
                            controller: "core/app/sso/authorizations", action: "show"
    assert_recognizes_route "https://#{CORE_APP_HOST}/sso/logout", :post,
                            controller: "core/app/sso/logouts", action: "create"
    assert_recognizes_route "https://#{CORE_APP_HOST}/health/liveness", :get,
                            controller: "core/app/health/livenesses", action: "show"
    assert_recognizes_route "https://#{CORE_APP_HOST}/health/readiness", :get,
                            controller: "core/app/health/readinesses", action: "show"
    assert_recognizes_route "https://#{CORE_APP_HOST}/health/startup", :get,
                            controller: "core/app/health/startups", action: "show"
  end

  test "core com route contract" do
    assert_recognizes_route "https://#{CORE_COM_HOST}/robots.txt", :get,
                            controller: "core/com/robots", action: "index"
    assert_recognizes_route "https://#{CORE_COM_HOST}/sitemap.xml", :get,
                            controller: "core/com/sitemaps", action: "show"
    assert_recognizes_route "https://#{CORE_COM_HOST}/csp-violation-report", :post,
                            controller: "core/com/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{CORE_COM_HOST}/oidc/backchannel/logout", :post,
                            controller: "core/com/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{CORE_COM_HOST}/health/liveness", :get,
                            controller: "core/com/health/livenesses", action: "show"
  end

  test "core org route contract" do
    assert_recognizes_route "https://#{CORE_ORG_HOST}/robots.txt", :get,
                            controller: "core/org/robots", action: "index"
    assert_recognizes_route "https://#{CORE_ORG_HOST}/sitemap.xml", :get,
                            controller: "core/org/sitemaps", action: "show"
    assert_recognizes_route "https://#{CORE_ORG_HOST}/csp-violation-report", :post,
                            controller: "core/org/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{CORE_ORG_HOST}/oidc/backchannel/logout", :post,
                            controller: "core/org/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{CORE_ORG_HOST}/health/liveness", :get,
                            controller: "core/org/health/livenesses", action: "show"
  end

  private

  def assert_recognizes_route(url, method, expected)
    recognized = Rails.application.routes.recognize_path(url, method: method)

    assert_equal expected[:controller], recognized[:controller],
                 "#{method.upcase} #{url} controller mismatch"
    assert_equal expected[:action], recognized[:action],
                 "#{method.upcase} #{url} action mismatch"
  end
end
