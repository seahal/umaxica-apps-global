# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseRouteContractTest < ActionDispatch::IntegrationTest
  fixtures_none!

  BASE_APP_HOST = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("BASE_STAFF_URL", "base.org.localhost")

  test "base app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/",
      method: :get,
    )

    assert_equal "base/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/health",
      method: :get,
    )

    assert_equal "base/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/app/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/app/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/settings",
      method: :get,
    )

    assert_equal "base/app/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/app/auth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/sign/out",
      method: :get,
    )

    assert_equal "base/app/sign_outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/app/sign_outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "base com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/",
      method: :get,
    )

    assert_equal "base/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health",
      method: :get,
    )

    assert_equal "base/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/com/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/com/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/settings",
      method: :get,
    )

    assert_equal "base/com/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/com/auth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out",
      method: :get,
    )

    assert_equal "base/com/sign_outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/com/sign_outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "base org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/",
      method: :get,
    )

    assert_equal "base/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "base/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/settings",
      method: :get,
    )

    assert_equal "base/org/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/org/auth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out",
      method: :get,
    )

    assert_equal "base/org/sign_outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/org/sign_outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "base remains a rails control-plane surface without provider endpoints" do
    [BASE_APP_HOST, BASE_COM_HOST, BASE_ORG_HOST].each do |host|
      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/settings",
        method: :get,
      )

      assert_equal "show", recognized[:action]
      assert_match(%r{\Abase/(app|com|org)/settings\z}, recognized[:controller])

      %w(/authorize /token /userinfo /jwks /oauth/authorize /oauth/token /oauth/userinfo /oauth/jwks).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oauth/token", method: :post)
      end
    end
  end
end
