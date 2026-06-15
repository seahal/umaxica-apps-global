# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRouteContractTest < ActionDispatch::IntegrationTest
  SIGN_APP_HOST = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  SIGN_COM_HOST = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
  SIGN_ORG_HOST = ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

  test "sign app route contract" do
    assert_recognizes_route "https://#{SIGN_APP_HOST}/robots.txt", :get,
                            controller: "sign/app/robots", action: "index"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/sitemap.xml", :get,
                            controller: "sign/app/sitemaps", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/csp-violation-report", :post,
                            controller: "sign/app/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/signed-out", :get,
                            controller: "sign/app/signed/outs", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/oidc/backchannel/logout", :post,
                            controller: "sign/app/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/sign/in/entrance", :get,
                            controller: "sign/app/sign/in/entrances", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/sign/up/entrance", :get,
                            controller: "sign/app/sign/up/entrances", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/health/liveness", :get,
                            controller: "sign/app/health/livenesses", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/health/readiness", :get,
                            controller: "sign/app/health/readinesses", action: "show"
    assert_recognizes_route "https://#{SIGN_APP_HOST}/health/startup", :get,
                            controller: "sign/app/health/startups", action: "show"
  end

  test "sign com route contract" do
    assert_recognizes_route "https://#{SIGN_COM_HOST}/robots.txt", :get,
                            controller: "sign/com/robots", action: "index"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/sitemap.xml", :get,
                            controller: "sign/com/sitemaps", action: "show"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/csp-violation-report", :post,
                            controller: "sign/com/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/signed-out", :get,
                            controller: "sign/com/signed/outs", action: "show"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/oidc/backchannel/logout", :post,
                            controller: "sign/com/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/sign/in/entrance", :get,
                            controller: "sign/com/sign/in/entrances", action: "show"
    assert_recognizes_route "https://#{SIGN_COM_HOST}/health/liveness", :get,
                            controller: "sign/com/health/livenesses", action: "show"
  end

  test "sign org route contract" do
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/robots.txt", :get,
                            controller: "sign/org/robots", action: "index"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/sitemap.xml", :get,
                            controller: "sign/org/sitemaps", action: "show"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/csp-violation-report", :post,
                            controller: "sign/org/csp_violation_reports", action: "create"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/signed-out", :get,
                            controller: "sign/org/signed/outs", action: "show"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/oidc/backchannel/logout", :post,
                            controller: "sign/org/oidc/backchannel/logouts", action: "create"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/sign/in/entrance", :get,
                            controller: "sign/org/sign/in/entrances", action: "show"
    assert_recognizes_route "https://#{SIGN_ORG_HOST}/health/liveness", :get,
                            controller: "sign/org/health/livenesses", action: "show"
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
