# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRouteContractTest < ActionDispatch::IntegrationTest
  fixtures_none!

  SIGN_APP_HOST = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  SIGN_COM_HOST = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
  SIGN_ORG_HOST = ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

  def assert_recognizes(expected, options)
    route = Rails.application.routes.recognize_path(options.fetch(:path), method: options.fetch(:method))

    assert_equal expected.fetch(:controller), route.fetch(:controller)
    assert_equal expected.fetch(:action), route.fetch(:action)
  end

  test "sign app route contract" do
    assert_recognizes(
      { controller: "sign/app/roots", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/healths", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/health/livenesses", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/health/readinesses", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/health/startups", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/robots", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sitemaps", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/outs", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/outs", action: "edit" },
      { path: "http://#{SIGN_APP_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/outs", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/sign/outs", action: "complete" },
      { path: "http://#{SIGN_APP_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/logout", method: :post)
    end

    assert_recognizes(
      { controller: "sign/app/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/oidc/backchannel/logout", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/dashboards", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/oidc/callbacks", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/oidc/authorizations", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/ups", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/up", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/up/email", method: :get)
    end

    assert_recognizes(
      { controller: "sign/app/sign/ins", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in", method: :get },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "sign/app/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/check", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/checks", action: "update" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/check", method: :patch },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/check/cancellations", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/check/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/secret_credentials", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/secret_credential/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/sign/in/secret_credentials", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/secret_credential", method: :post },
    )

    [
      { controller: "sign/app/settings", action: "show", path: "/settings" },
      { controller: "sign/app/settings/passkeys", action: "index", path: "/settings/passkeys" },
      { controller: "sign/app/settings/sessions", action: "index", path: "/settings/sessions" },
      { controller: "sign/app/settings/activities", action: "index", path: "/settings/activities" },
    ].each do |route|
      assert_recognizes(
        { controller: route[:controller], action: route[:action] },
        { path: "http://#{SIGN_APP_HOST}#{route[:path]}", method: :get },
      )
    end
  end

  test "sign app-only route contract" do
    assert_recognizes(
      { controller: "sign/app/social/apple/connections", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/connection", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/social/apple/disconnections", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/disconnection", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/social/google/connections", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/social/google/connection", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/social/google/disconnections", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/social/google/disconnection", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "failure" },
      { path: "http://#{SIGN_APP_HOST}/social/failure", method: :get },
    )

    %w(/auth /auth/callback /auth/logout /auth/google_app/callback /auth/apple/callback /auth/failure
       /social/auth/google_app/continue /social/auth/apple/continue).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "sign/app/social/authentications", action: "continue" },
      { path: "http://#{SIGN_APP_HOST}/social/google/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/social/authentications", action: "continue" },
      { path: "http://#{SIGN_APP_HOST}/social/google/sign/up", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/social/authentications", action: "continue" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/social/authentications", action: "continue" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/sign/up", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/auth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :post },
    )

    assert_recognizes(
      { controller: "sign/app/settings/totps", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/settings/totps", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/settings/apples", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/settings/apple", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/settings/googles", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/settings/google", method: :get },
    )

    assert_recognizes(
      { controller: "sign/app/settings/secret_credentials", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/settings/secret_credentials", method: :get },
    )
  end

  test "sign com route contract" do
    assert_recognizes(
      { controller: "sign/com/roots", action: "index" },
      { path: "http://#{SIGN_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/healths", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/health/livenesses", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/health/readinesses", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/health/startups", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/robots", action: "index" },
      { path: "http://#{SIGN_COM_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sitemaps", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/outs", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/outs", action: "edit" },
      { path: "http://#{SIGN_COM_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/outs", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/sign/outs", action: "complete" },
      { path: "http://#{SIGN_COM_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/logout", method: :post)
    end

    assert_recognizes(
      { controller: "sign/com/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/oidc/backchannel/logout", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/dashboards", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/oidc/callbacks", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/oidc/authorizations", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/ups", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/up", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/up/email", method: :get)
    end

    assert_recognizes(
      { controller: "sign/com/sign/ins", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in", method: :get },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "sign/com/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/check", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/checks", action: "update" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/check", method: :patch },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/check/cancellations", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/check/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/secret_credentials", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/secret_credential/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/com/sign/in/secret_credentials", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/secret_credential", method: :post },
    )

    [
      { controller: "sign/com/settings", action: "show", path: "/settings" },
      { controller: "sign/com/settings/passkeys", action: "index", path: "/settings/passkeys" },
      { controller: "sign/com/settings/sessions", action: "index", path: "/settings/sessions" },
      { controller: "sign/com/settings/activities", action: "index", path: "/settings/activities" },
    ].each do |route|
      assert_recognizes(
        { controller: route[:controller], action: route[:action] },
        { path: "http://#{SIGN_COM_HOST}#{route[:path]}", method: :get },
      )
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "sign org route contract" do
    assert_recognizes(
      { controller: "sign/org/roots", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/healths", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/health/livenesses", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/health/readinesses", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/health/startups", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/robots", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sitemaps", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/outs", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/outs", action: "edit" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/outs", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/sign/outs", action: "complete" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/logout", method: :post)
    end

    assert_recognizes(
      { controller: "sign/org/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/oidc/backchannel/logout", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/dashboards", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/oidc/callbacks", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/oidc/authorizations", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/ups", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/up/email", method: :get)
    end

    assert_recognizes(
      { controller: "sign/org/sign/ins", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/up/invitations", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up/invitations/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/up/invitations", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up/invitations", method: :post },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "sign/org/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/check", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/checks", action: "update" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/check", method: :patch },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/check/cancellations", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/check/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/secret_credentials", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/secret_credential/new", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/sign/in/secret_credentials", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/secret_credential", method: :post },
    )
  end

  test "sign org route contract (continued)" do
    assert_recognizes(
      { controller: "sign/org/settings", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/settings", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/settings/passkeys", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/settings/passkeys", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/settings/sessions", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/settings/sessions", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/settings/activities", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/settings/activities", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/configurations", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/configuration", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/accounts", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/accounts", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/iam", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/iam", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/system", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/system", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/audit", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/audit", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/support", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/support", method: :get },
    )

    assert_recognizes(
      { controller: "sign/org/billing", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/billing", method: :get },
    )
  end

  test "sign negative route contract" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/sso/logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/auth/acme/callback",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/sso/logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/auth/acme/callback",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/sso/logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/auth/acme/callback",
        method: :get,
      )
    end

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
  # rubocop:enable Minitest/MultipleAssertions

  test "sign remains a relying party and does not expose oauth provider endpoints" do
    [SIGN_APP_HOST, SIGN_COM_HOST, SIGN_ORG_HOST].each do |host|
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
