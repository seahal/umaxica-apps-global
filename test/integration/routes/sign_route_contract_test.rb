# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRouteContractTest < ActionDispatch::IntegrationTest
  SIGN_APP_HOST = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  SIGN_COM_HOST = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
  SIGN_ORG_HOST = ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

  test "sign app route contract" do
    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/", method: :get)

    assert_equal "sign/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "sign/app/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/health", method: :get)

    assert_equal "sign/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "sign/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "sign/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "sign/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/robots.txt", method: :get)

    assert_equal "sign/app/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sitemap.xml", method: :get)

    assert_equal "sign/app/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/signed-out",
      method: :get,
    )

    assert_equal "sign/app/signed/outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "sign/app/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "sign/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/dashboard", method: :get)

    assert_equal "sign/app/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "sign/app/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/up/entrance",
      method: :get,
    )

    assert_equal "sign/app/sign/up/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/entrance",
      method: :get,
    )

    assert_equal "sign/app/sign/in/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/guard",
      method: :get,
    )

    assert_equal "sign/app/sign/in/guards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/check",
      method: :get,
    )

    assert_equal "sign/app/sign/in/checks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/check/cancellation",
      method: :post,
    )

    assert_equal "sign/app/sign/in/check/cancellations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/challenge",
      method: :get,
    )

    assert_equal "sign/app/sign/in/challenges", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/passkey/new",
      method: :get,
    )

    assert_equal "sign/app/sign/in/passkeys", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/passkey/options",
      method: :post,
    )

    assert_equal "sign/app/sign/in/passkey/options", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/passkey/verification",
      method: :post,
    )

    assert_equal "sign/app/sign/in/passkey/verifications", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/secret_credential/new",
      method: :get,
    )

    assert_equal "sign/app/sign/in/secret_credentials", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/sign/in/secret_credential",
      method: :post,
    )

    assert_equal "sign/app/sign/in/secret_credentials", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/settings", method: :get)

    assert_equal "sign/app/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/passkeys",
      method: :get,
    )

    assert_equal "sign/app/settings/passkeys", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/sessions",
      method: :get,
    )

    assert_equal "sign/app/settings/sessions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/activities",
      method: :get,
    )

    assert_equal "sign/app/settings/activities", recognized[:controller]
    assert_equal "index", recognized[:action]
  end

  test "sign app-only route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/social/apple/connection",
      method: :get,
    )

    assert_equal "sign/app/social/apple/connections", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/social/apple/disconnection",
      method: :post,
    )

    assert_equal "sign/app/social/apple/disconnections", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/social/google/connection",
      method: :get,
    )

    assert_equal "sign/app/social/google/connections", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/social/google/disconnection",
      method: :post,
    )

    assert_equal "sign/app/social/google/disconnections", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/auth/google_app/callback",
      method: :get,
    )

    assert_equal "sign/app/auth/omniauth_callbacks", recognized[:controller]
    assert_equal "omniauth", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/auth/apple/callback",
      method: :get,
    )

    assert_equal "sign/app/auth/omniauth_callbacks", recognized[:controller]
    assert_equal "omniauth", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/auth/apple/callback",
      method: :post,
    )

    assert_equal "sign/app/auth/omniauth_callbacks", recognized[:controller]
    assert_equal "omniauth", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/auth/failure",
      method: :get,
    )

    assert_equal "sign/app/auth/omniauth_callbacks", recognized[:controller]
    assert_equal "failure", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/totps",
      method: :get,
    )

    assert_equal "sign/app/settings/totps", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/apple",
      method: :get,
    )

    assert_equal "sign/app/settings/apples", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/google",
      method: :get,
    )

    assert_equal "sign/app/settings/googles", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_APP_HOST}/settings/secrets",
      method: :get,
    )

    assert_equal "sign/app/settings/secrets", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "sign com route contract" do
    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/", method: :get)

    assert_equal "sign/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "sign/com/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/health", method: :get)

    assert_equal "sign/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "sign/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "sign/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "sign/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/robots.txt", method: :get)

    assert_equal "sign/com/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sitemap.xml", method: :get)

    assert_equal "sign/com/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/signed-out",
      method: :get,
    )

    assert_equal "sign/com/signed/outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "sign/com/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "sign/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/dashboard", method: :get)

    assert_equal "sign/com/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "sign/com/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/up/entrance",
      method: :get,
    )

    assert_equal "sign/com/sign/up/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/entrance",
      method: :get,
    )

    assert_equal "sign/com/sign/in/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/guard",
      method: :get,
    )

    assert_equal "sign/com/sign/in/guards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/check",
      method: :get,
    )

    assert_equal "sign/com/sign/in/checks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/check/cancellation",
      method: :post,
    )

    assert_equal "sign/com/sign/in/check/cancellations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/challenge",
      method: :get,
    )

    assert_equal "sign/com/sign/in/challenges", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/passkey/new",
      method: :get,
    )

    assert_equal "sign/com/sign/in/passkeys", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/passkey/options",
      method: :post,
    )

    assert_equal "sign/com/sign/in/passkey/options", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/passkey/verification",
      method: :post,
    )

    assert_equal "sign/com/sign/in/passkey/verifications", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/secret_credential/new",
      method: :get,
    )

    assert_equal "sign/com/sign/in/secret_credentials", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/sign/in/secret_credential",
      method: :post,
    )

    assert_equal "sign/com/sign/in/secret_credentials", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/settings", method: :get)

    assert_equal "sign/com/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/settings/passkeys",
      method: :get,
    )

    assert_equal "sign/com/settings/passkeys", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/settings/sessions",
      method: :get,
    )

    assert_equal "sign/com/settings/sessions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_COM_HOST}/settings/activities",
      method: :get,
    )

    assert_equal "sign/com/settings/activities", recognized[:controller]
    assert_equal "index", recognized[:action]
  end

  test "sign org route contract" do
    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/", method: :get)

    assert_equal "sign/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/.well-known/jwks.json",
      method: :get,
    )

    assert_equal "sign/org/well_known/jwks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/health", method: :get)

    assert_equal "sign/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "sign/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "sign/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "sign/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/robots.txt", method: :get)

    assert_equal "sign/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sitemap.xml", method: :get)

    assert_equal "sign/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/signed-out",
      method: :get,
    )

    assert_equal "sign/org/signed/outs", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/oidc/backchannel/logout",
      method: :post,
    )

    assert_equal "sign/org/oidc/backchannel/logouts", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "sign/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/dashboard", method: :get)

    assert_equal "sign/org/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/auth/callback",
      method: :get,
    )

    assert_equal "sign/org/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/up/entrance",
      method: :get,
    )

    assert_equal "sign/org/sign/up/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/up/invitations/new",
      method: :get,
    )

    assert_equal "sign/org/sign/up/invitations", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/up/invitations",
      method: :post,
    )

    assert_equal "sign/org/sign/up/invitations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/entrance",
      method: :get,
    )

    assert_equal "sign/org/sign/in/entrances", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/guard",
      method: :get,
    )

    assert_equal "sign/org/sign/in/guards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/check",
      method: :get,
    )

    assert_equal "sign/org/sign/in/checks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/check/cancellation",
      method: :post,
    )

    assert_equal "sign/org/sign/in/check/cancellations", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/challenge",
      method: :get,
    )

    assert_equal "sign/org/sign/in/challenges", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/passkey/new",
      method: :get,
    )

    assert_equal "sign/org/sign/in/passkeys", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/passkey/options",
      method: :post,
    )

    assert_equal "sign/org/sign/in/passkey/options", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/passkey/verification",
      method: :post,
    )

    assert_equal "sign/org/sign/in/passkey/verifications", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/secret_credential/new",
      method: :get,
    )

    assert_equal "sign/org/sign/in/secret_credentials", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/sign/in/secret_credential",
      method: :post,
    )

    assert_equal "sign/org/sign/in/secret_credentials", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/settings", method: :get)

    assert_equal "sign/org/settings", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/settings/passkeys",
      method: :get,
    )

    assert_equal "sign/org/settings/passkeys", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/settings/sessions",
      method: :get,
    )

    assert_equal "sign/org/settings/sessions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/settings/activities",
      method: :get,
    )

    assert_equal "sign/org/settings/activities", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{SIGN_ORG_HOST}/configuration",
      method: :get,
    )

    assert_equal "sign/org/configurations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/accounts", method: :get)

    assert_equal "sign/org/accounts", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/iam", method: :get)

    assert_equal "sign/org/iam", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/system", method: :get)

    assert_equal "sign/org/system", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/audit", method: :get)

    assert_equal "sign/org/audit", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/support", method: :get)

    assert_equal "sign/org/support", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/billing", method: :get)

    assert_equal "sign/org/billing", recognized[:controller]
    assert_equal "index", recognized[:action]
  end

  test "sign negative route contract" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/settings/secrets",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/settings/secrets",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/sign/in/secret/new",
        method: :get,
      )
    end
  end
end
