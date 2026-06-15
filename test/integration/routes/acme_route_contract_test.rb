# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeRouteContractTest < ActionDispatch::IntegrationTest
  ACME_APP_HOST = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  ACME_COM_HOST = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
  ACME_ORG_HOST = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

  test "acme app route contract" do
    assert_recognizes_route "https://#{ACME_APP_HOST}/robots.txt", :get,
                            controller: "acme/app/robots", action: "index"
    assert_recognizes_route "https://#{ACME_APP_HOST}/sitemap.xml", :get,
                            controller: "acme/app/sitemaps", action: "show"
    assert_recognizes_route "https://#{ACME_APP_HOST}/csp-violation-report", :post,
                            controller: "acme/app/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{ACME_APP_HOST}/sign/out", :delete,
                            controller: "acme/app/sign/outs", action: "destroy"
    assert_recognizes_route "https://#{ACME_APP_HOST}/oauth/authorize", :get,
                            controller: "acme/app/oauth/authorizations", action: "show"
    assert_recognizes_route "https://#{ACME_APP_HOST}/oauth/token", :post,
                            controller: "acme/app/oauth/tokens", action: "create"
    assert_recognizes_route "https://#{ACME_APP_HOST}/oauth/userinfo", :get,
                            controller: "acme/app/oauth/userinfos", action: "show"
    assert_recognizes_route "https://#{ACME_APP_HOST}/oauth/revoke", :post,
                            controller: "acme/app/oauth/revocations", action: "create"
    assert_recognizes_route "https://#{ACME_APP_HOST}/oidc/logout", :post,
                            controller: "acme/app/oidc/logouts", action: "create"
    assert_recognizes_route "https://#{ACME_APP_HOST}/health/liveness", :get,
                            controller: "acme/app/health/livenesses", action: "show"
    assert_recognizes_route "https://#{ACME_APP_HOST}/health/readiness", :get,
                            controller: "acme/app/health/readinesses", action: "show"
    assert_recognizes_route "https://#{ACME_APP_HOST}/health/startup", :get,
                            controller: "acme/app/health/startups", action: "show"
  end

  test "acme com route contract" do
    assert_recognizes_route "https://#{ACME_COM_HOST}/robots.txt", :get,
                            controller: "acme/com/robots", action: "index"
    assert_recognizes_route "https://#{ACME_COM_HOST}/sitemap.xml", :get,
                            controller: "acme/com/sitemaps", action: "show"
    assert_recognizes_route "https://#{ACME_COM_HOST}/csp-violation-report", :post,
                            controller: "acme/com/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{ACME_COM_HOST}/sign/out", :delete,
                            controller: "acme/com/sign/outs", action: "destroy"
    assert_recognizes_route "https://#{ACME_COM_HOST}/oauth/authorize", :get,
                            controller: "acme/com/oauth/authorizations", action: "show"
    assert_recognizes_route "https://#{ACME_COM_HOST}/oauth/token", :post,
                            controller: "acme/com/oauth/tokens", action: "create"
    assert_recognizes_route "https://#{ACME_COM_HOST}/oauth/userinfo", :get,
                            controller: "acme/com/oauth/userinfos", action: "show"
    assert_recognizes_route "https://#{ACME_COM_HOST}/oauth/revoke", :post,
                            controller: "acme/com/oauth/revocations", action: "create"
    assert_recognizes_route "https://#{ACME_COM_HOST}/oidc/logout", :post,
                            controller: "acme/com/oidc/logouts", action: "create"
    assert_recognizes_route "https://#{ACME_COM_HOST}/health/liveness", :get,
                            controller: "acme/com/health/livenesses", action: "show"
  end

  test "acme org route contract" do
    assert_recognizes_route "https://#{ACME_ORG_HOST}/robots.txt", :get,
                            controller: "acme/org/robots", action: "index"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/sitemap.xml", :get,
                            controller: "acme/org/sitemaps", action: "show"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/csp-violation-report", :post,
                            controller: "acme/org/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/sign/out", :delete,
                            controller: "acme/org/sign/outs", action: "destroy"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/oauth/authorize", :get,
                            controller: "acme/org/oauth/authorizations", action: "show"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/oauth/token", :post,
                            controller: "acme/org/oauth/tokens", action: "create"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/oauth/userinfo", :get,
                            controller: "acme/org/oauth/userinfos", action: "show"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/oauth/revoke", :post,
                            controller: "acme/org/oauth/revocations", action: "create"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/oidc/logout", :post,
                            controller: "acme/org/oidc/logouts", action: "create"
    assert_recognizes_route "https://#{ACME_ORG_HOST}/health/liveness", :get,
                            controller: "acme/org/health/livenesses", action: "show"
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
