# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeRouteContractTest < ActionDispatch::IntegrationTest
  ACME_APP_HOST = ENV.fetch("ACME_SERVICE_URL", "app.localhost")
  ACME_COM_HOST = ENV.fetch("ACME_CORPORATE_URL", "com.localhost")
  ACME_ORG_HOST = ENV.fetch("ACME_STAFF_URL", "org.localhost")

  test "acme app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/",
      method: :get,
    )

    assert_equal "acme/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "acme/app/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/.well-known/openid-configuration",
      method: :get,
    )

    assert_equal "acme/app/well_known/discoveries", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/health",
      method: :get,
    )

    assert_equal "acme/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "acme/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "acme/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "acme/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "acme/app/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "acme/app/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "acme/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/welcome",
      method: :get,
    )

    assert_equal "acme/app/welcomes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/dashboard",
      method: :get,
    )

    assert_equal "acme/app/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/selector",
      method: :get,
    )

    assert_equal "acme/app/selectors", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/selector",
      method: :patch,
    )

    assert_equal "acme/app/selectors", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "acme/app/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "acme/app/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "acme/app/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oidc/logout",
      method: :get,
    )

    assert_equal "acme/app/oidc/logouts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oidc/logout",
      method: :post,
    )

    assert_equal "acme/app/oidc/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oauth/authorize",
      method: :get,
    )

    assert_equal "acme/app/oauth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oauth/token",
      method: :post,
    )

    assert_equal "acme/app/oauth/tokens", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oauth/userinfo",
      method: :get,
    )

    assert_equal "acme/app/oauth/userinfos", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oauth/revoke",
      method: :post,
    )

    assert_equal "acme/app/oauth/revocations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/oauth/jwks",
      method: :get,
    )

    assert_equal "acme/app/oauth/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/avatar",
      method: :get,
    )

    assert_equal "acme/app/avatars", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/organization",
      method: :get,
    )

    assert_equal "acme/app/organizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/account",
      method: :get,
    )

    assert_equal "acme/app/accounts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/identity",
      method: :get,
    )

    assert_equal "acme/app/identities", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_APP_HOST}/settings",
      method: :get,
    )

    assert_equal "acme/app/settings", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "acme com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/",
      method: :get,
    )

    assert_equal "acme/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "acme/com/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/.well-known/openid-configuration",
      method: :get,
    )

    assert_equal "acme/com/well_known/discoveries", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/health",
      method: :get,
    )

    assert_equal "acme/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "acme/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "acme/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "acme/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "acme/com/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "acme/com/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "acme/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/welcome",
      method: :get,
    )

    assert_equal "acme/com/welcomes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/dashboard",
      method: :get,
    )

    assert_equal "acme/com/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/selector",
      method: :get,
    )

    assert_equal "acme/com/selectors", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/selector",
      method: :patch,
    )

    assert_equal "acme/com/selectors", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "acme/com/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "acme/com/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "acme/com/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oidc/logout",
      method: :get,
    )

    assert_equal "acme/com/oidc/logouts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oidc/logout",
      method: :post,
    )

    assert_equal "acme/com/oidc/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oauth/authorize",
      method: :get,
    )

    assert_equal "acme/com/oauth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oauth/token",
      method: :post,
    )

    assert_equal "acme/com/oauth/tokens", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oauth/userinfo",
      method: :get,
    )

    assert_equal "acme/com/oauth/userinfos", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oauth/revoke",
      method: :post,
    )

    assert_equal "acme/com/oauth/revocations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/oauth/jwks",
      method: :get,
    )

    assert_equal "acme/com/oauth/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/account",
      method: :get,
    )

    assert_equal "acme/com/accounts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/identity",
      method: :get,
    )

    assert_equal "acme/com/identities", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_COM_HOST}/settings",
      method: :get,
    )

    assert_equal "acme/com/settings", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "acme org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/",
      method: :get,
    )

    assert_equal "acme/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "acme/org/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "acme/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "acme/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "acme/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "acme/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "acme/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "acme/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "acme/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/welcome",
      method: :get,
    )

    assert_equal "acme/org/welcomes", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/dashboard",
      method: :get,
    )

    assert_equal "acme/org/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/selector",
      method: :get,
    )

    assert_equal "acme/org/selectors", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/selector",
      method: :patch,
    )

    assert_equal "acme/org/selectors", recognized[:controller]
    assert_equal "update", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "acme/org/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/sso/authorize",
      method: :get,
    )

    assert_equal "acme/org/sso/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/sso/logout",
      method: :post,
    )

    assert_equal "acme/org/sso/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oidc/logout",
      method: :get,
    )

    assert_equal "acme/org/oidc/logouts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oidc/logout",
      method: :post,
    )

    assert_equal "acme/org/oidc/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oauth/authorize",
      method: :get,
    )

    assert_equal "acme/org/oauth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oauth/token",
      method: :post,
    )

    assert_equal "acme/org/oauth/tokens", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oauth/userinfo",
      method: :get,
    )

    assert_equal "acme/org/oauth/userinfos", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oauth/revoke",
      method: :post,
    )

    assert_equal "acme/org/oauth/revocations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/oauth/jwks",
      method: :get,
    )

    assert_equal "acme/org/oauth/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/avatar",
      method: :get,
    )

    assert_equal "acme/org/avatars", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/organization",
      method: :get,
    )

    assert_equal "acme/org/organizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/account",
      method: :get,
    )

    assert_equal "acme/org/accounts", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/configuration",
      method: :get,
    )

    assert_equal "acme/org/configurations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/iam",
      method: :get,
    )

    assert_equal "acme/org/iam", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/system",
      method: :get,
    )

    assert_equal "acme/org/system", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/audit",
      method: :get,
    )

    assert_equal "acme/org/audit", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/support",
      method: :get,
    )

    assert_equal "acme/org/support", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/billing",
      method: :get,
    )

    assert_equal "acme/org/billing", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{ACME_ORG_HOST}/settings",
      method: :get,
    )

    assert_equal "acme/org/settings", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "acme retired routes do not resolve" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_APP_HOST}/__dev/r18/gate",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_APP_HOST}/oauth/user_info",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_APP_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_COM_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_ORG_HOST}/accounts",
        method: :get,
      )
    end
  end
end
