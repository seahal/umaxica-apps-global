# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeRouteContractTest < ActionDispatch::IntegrationTest
  ACME_APP_HOST = ENV.fetch("ACME_SERVICE_URL", "app.localhost")
  ACME_COM_HOST = ENV.fetch("ACME_CORPORATE_URL", "com.localhost")
  ACME_ORG_HOST = ENV.fetch("ACME_STAFF_URL", "org.localhost")

  test "acme app static and health routes" do
    assert_recognizes(
      { controller: "acme/app/roots", action: "index" },
      { path: "http://#{ACME_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/well_known/jwks", action: "show" },
      { path: "http://#{ACME_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/well_known/discoveries", action: "show" },
      { path: "http://#{ACME_APP_HOST}/.well-known/openid-configuration", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/healths", action: "show" },
      { path: "http://#{ACME_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/health/livenesses", action: "show" },
      { path: "http://#{ACME_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/health/readinesses", action: "show" },
      { path: "http://#{ACME_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/health/startups", action: "show" },
      { path: "http://#{ACME_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/robots", action: "index" },
      { path: "http://#{ACME_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/sitemaps", action: "show" },
      { path: "http://#{ACME_APP_HOST}/sitemap.xml", method: :get },
    )
  end

  test "acme app auth routes" do
    assert_recognizes(
      { controller: "acme/app/csp_violation_reports", action: "create" },
      { path: "http://#{ACME_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "acme/app/welcomes", action: "show" },
      { path: "http://#{ACME_APP_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/dashboards", action: "show" },
      { path: "http://#{ACME_APP_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/selectors", action: "show" },
      { path: "http://#{ACME_APP_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/selectors", action: "update" },
      { path: "http://#{ACME_APP_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "acme/app/auth/callbacks", action: "show" },
      { path: "http://#{ACME_APP_HOST}/auth/callback", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/auth/authorizations", action: "show" },
      { path: "http://#{ACME_APP_HOST}/auth", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/auth/logouts", action: "create" },
      { path: "http://#{ACME_APP_HOST}/auth/logout", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/sso/logout", method: :post)
    end

    assert_recognizes(
      { controller: "acme/app/oidc/logouts", action: "show" },
      { path: "http://#{ACME_APP_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/oidc/logouts", action: "create" },
      { path: "http://#{ACME_APP_HOST}/oidc/logout", method: :post },
    )
  end

  test "acme app oauth and account routes" do
    assert_recognizes(
      { controller: "acme/app/oauth/authorizations", action: "show" },
      { path: "http://#{ACME_APP_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/oauth/tokens", action: "create" },
      { path: "http://#{ACME_APP_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "acme/app/oauth/userinfos", action: "show" },
      { path: "http://#{ACME_APP_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/oauth/revocations", action: "create" },
      { path: "http://#{ACME_APP_HOST}/oauth/revoke", method: :post },
    )

    assert_recognizes(
      { controller: "acme/app/oauth/jwks", action: "show" },
      { path: "http://#{ACME_APP_HOST}/oauth/jwks", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/avatars", action: "show" },
      { path: "http://#{ACME_APP_HOST}/avatar", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/organizations", action: "show" },
      { path: "http://#{ACME_APP_HOST}/organization", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/accounts", action: "show" },
      { path: "http://#{ACME_APP_HOST}/account", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/identities", action: "show" },
      { path: "http://#{ACME_APP_HOST}/identity", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/settings", action: "show" },
      { path: "http://#{ACME_APP_HOST}/settings", method: :get },
    )
  end

  test "acme com route contract" do
    assert_recognizes(
      { controller: "acme/com/roots", action: "index" },
      { path: "http://#{ACME_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/well_known/jwks", action: "show" },
      { path: "http://#{ACME_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/well_known/discoveries", action: "show" },
      { path: "http://#{ACME_COM_HOST}/.well-known/openid-configuration", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/healths", action: "show" },
      { path: "http://#{ACME_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/health/livenesses", action: "show" },
      { path: "http://#{ACME_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/health/readinesses", action: "show" },
      { path: "http://#{ACME_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/health/startups", action: "show" },
      { path: "http://#{ACME_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/robots", action: "index" },
      { path: "http://#{ACME_COM_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/sitemaps", action: "show" },
      { path: "http://#{ACME_COM_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/csp_violation_reports", action: "create" },
      { path: "http://#{ACME_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "acme/com/welcomes", action: "show" },
      { path: "http://#{ACME_COM_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/dashboards", action: "show" },
      { path: "http://#{ACME_COM_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/selectors", action: "show" },
      { path: "http://#{ACME_COM_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/selectors", action: "update" },
      { path: "http://#{ACME_COM_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "acme/com/auth/callbacks", action: "show" },
      { path: "http://#{ACME_COM_HOST}/auth/callback", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/auth/authorizations", action: "show" },
      { path: "http://#{ACME_COM_HOST}/auth", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/auth/logouts", action: "create" },
      { path: "http://#{ACME_COM_HOST}/auth/logout", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_COM_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_COM_HOST}/sso/logout", method: :post)
    end

    assert_recognizes(
      { controller: "acme/com/oidc/logouts", action: "show" },
      { path: "http://#{ACME_COM_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/oidc/logouts", action: "create" },
      { path: "http://#{ACME_COM_HOST}/oidc/logout", method: :post },
    )

    assert_recognizes(
      { controller: "acme/com/oauth/authorizations", action: "show" },
      { path: "http://#{ACME_COM_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/oauth/tokens", action: "create" },
      { path: "http://#{ACME_COM_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "acme/com/oauth/userinfos", action: "show" },
      { path: "http://#{ACME_COM_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/oauth/revocations", action: "create" },
      { path: "http://#{ACME_COM_HOST}/oauth/revoke", method: :post },
    )

    assert_recognizes(
      { controller: "acme/com/oauth/jwks", action: "show" },
      { path: "http://#{ACME_COM_HOST}/oauth/jwks", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/accounts", action: "show" },
      { path: "http://#{ACME_COM_HOST}/account", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/identities", action: "show" },
      { path: "http://#{ACME_COM_HOST}/identity", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/settings", action: "show" },
      { path: "http://#{ACME_COM_HOST}/settings", method: :get },
    )
  end

  test "acme org route contract" do
    assert_recognizes(
      { controller: "acme/org/roots", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/well_known/jwks", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/healths", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/health/livenesses", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/health/readinesses", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/health/startups", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/robots", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/sitemaps", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/csp_violation_reports", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "acme/org/welcomes", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/dashboards", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/selectors", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/selectors", action: "update" },
      { path: "http://#{ACME_ORG_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "acme/org/auth/callbacks", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/auth/callback", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/auth/authorizations", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/auth", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/auth/logouts", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/auth/logout", method: :post },
    )
  end

  test "acme org route contract (continued)" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/sso/logout", method: :post)
    end

    assert_recognizes(
      { controller: "acme/org/oidc/logouts", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/oidc/logouts", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/oidc/logout", method: :post },
    )

    assert_recognizes(
      { controller: "acme/org/oauth/authorizations", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/oauth/tokens", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "acme/org/oauth/userinfos", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/oauth/revocations", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/oauth/revoke", method: :post },
    )

    assert_recognizes(
      { controller: "acme/org/oauth/jwks", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/oauth/jwks", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/avatars", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/avatar", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/organizations", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/organization", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/accounts", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/account", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/configurations", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/configuration", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/iam", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/iam", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/system", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/system", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/audit", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/audit", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/support", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/support", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/billing", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/billing", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/settings", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/settings", method: :get },
    )
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

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_APP_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ACME_APP_HOST}/auth/acme/callback",
        method: :get,
      )
    end
  end
end
