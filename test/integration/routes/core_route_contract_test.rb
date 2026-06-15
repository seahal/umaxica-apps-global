# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRouteContractTest < ActionDispatch::IntegrationTest
  CORE_APP_HOST = ENV.fetch("CORE_SERVICE_URL", "core.app.localhost")
  CORE_COM_HOST = ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost")
  CORE_ORG_HOST = ENV.fetch("CORE_STAFF_URL", "core.org.localhost")
  CORE_NET_HOST = ENV.fetch("CORE_NETWORK_URL", "core.net.localhost")
  CORE_DEV_HOST = ENV.fetch("CORE_DEVELOPER_URL", "core.dev.localhost")

  test "core app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/",
      method: :get,
    )

    assert_equal "core/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "core/app/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/health",
      method: :get,
    )

    assert_equal "core/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "core/app/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "core/app/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/web/v0/cookie",
      method: :get,
    )

    assert_equal "core/app/web/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/web/v0/cookie",
      method: :patch,
    )

    assert_equal "core/app/web/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/web/v0/theme",
      method: :get,
    )

    assert_equal "core/app/web/v0/themes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/web/v0/theme",
      method: :patch,
    )

    assert_equal "core/app/web/v0/themes", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/edge/v0/cookie",
      method: :get,
    )

    assert_equal "core/app/edge/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/edge/v0/cookie",
      method: :patch,
    )

    assert_equal "core/app/edge/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/edge/v0/dbsc",
      method: :post,
    )

    assert_equal "core/app/edge/v0/dbsc", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/api/v0/session",
      method: :get,
    )

    assert_equal "core/app/api/v0/sessions", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/api/v0/token/refresh",
      method: :post,
    )

    assert_equal "core/app/api/v0/token/refreshes", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "core/app/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "core/app/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "core/app/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_APP_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "core/app/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/",
      method: :get,
    )

    assert_equal "core/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "core/com/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/health",
      method: :get,
    )

    assert_equal "core/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "core/com/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "core/com/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/web/v0/cookie",
      method: :get,
    )

    assert_equal "core/com/web/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/web/v0/cookie",
      method: :patch,
    )

    assert_equal "core/com/web/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/web/v0/theme",
      method: :get,
    )

    assert_equal "core/com/web/v0/themes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/web/v0/theme",
      method: :patch,
    )

    assert_equal "core/com/web/v0/themes", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/edge/v0/cookie",
      method: :get,
    )

    assert_equal "core/com/edge/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/edge/v0/cookie",
      method: :patch,
    )

    assert_equal "core/com/edge/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/edge/v0/dbsc",
      method: :post,
    )

    assert_equal "core/com/edge/v0/dbsc", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/api/v0/session",
      method: :get,
    )

    assert_equal "core/com/api/v0/sessions", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/api/v0/token/refresh",
      method: :post,
    )

    assert_equal "core/com/api/v0/token/refreshes", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "core/com/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "core/com/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "core/com/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_COM_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "core/com/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/",
      method: :get,
    )

    assert_equal "core/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "core/org/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "core/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "core/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "core/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/configuration",
      method: :get,
    )

    assert_equal "core/org/configurations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/web/v0/cookie",
      method: :get,
    )

    assert_equal "core/org/web/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/web/v0/cookie",
      method: :patch,
    )

    assert_equal "core/org/web/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/web/v0/theme",
      method: :get,
    )

    assert_equal "core/org/web/v0/themes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/web/v0/theme",
      method: :patch,
    )

    assert_equal "core/org/web/v0/themes", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/edge/v0/cookie",
      method: :get,
    )

    assert_equal "core/org/edge/v0/cookies", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/edge/v0/cookie",
      method: :patch,
    )

    assert_equal "core/org/edge/v0/cookies", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/edge/v0/dbsc",
      method: :post,
    )

    assert_equal "core/org/edge/v0/dbsc", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/api/v0/session",
      method: :get,
    )

    assert_equal "core/org/api/v0/sessions", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/api/v0/token/refresh",
      method: :post,
    )

    assert_equal "core/org/api/v0/token/refreshes", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "core/org/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "core/org/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "core/org/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_ORG_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "core/org/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core net route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/",
      method: :get,
    )

    assert_equal "core/net/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health",
      method: :get,
    )

    assert_equal "core/net/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/net/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/net/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/net/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_NET_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/net/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core dev route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/",
      method: :get,
    )

    assert_equal "core/dev/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health",
      method: :get,
    )

    assert_equal "core/dev/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "core/dev/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "core/dev/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/health/startup",
      method: :get,
    )

    assert_equal "core/dev/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{CORE_DEV_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "core/dev/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "core retired routes do not resolve" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_APP_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_COM_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{CORE_ORG_HOST}/accounts",
        method: :get,
      )
    end
  end
end
