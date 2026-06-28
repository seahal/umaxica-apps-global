# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  CORE_APP_HOST = BOOT_HOSTS.core_service.host
  CORE_COM_HOST = BOOT_HOSTS.core_corporate.host
  CORE_ORG_HOST = BOOT_HOSTS.core_staff.host
  CORE_NET_HOST = ENV["PRIVATE_CORE_NETWORK_URL"] || ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost")
  CORE_DEV_HOST = ENV["PRIVATE_CORE_DEVELOPER_URL"] || ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost")

  test "core surfaces do not expose dashboards" do
    [CORE_APP_HOST, CORE_COM_HOST, CORE_ORG_HOST, CORE_NET_HOST, CORE_DEV_HOST].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/dashboard", method: :get)
      end
    end
  end

  test "core app route contract" do
    assert_recognizes(
      { controller: "core/app/roots", action: "index" },
      { path: "http://#{CORE_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/well_known/jwks", action: "show" },
      { path: "http://#{CORE_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/healths", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/livenesses", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/readinesses", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/health/startups", action: "show" },
      { path: "http://#{CORE_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/robots", action: "index" },
      { path: "http://#{CORE_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sitemaps", action: "show" },
      { path: "http://#{CORE_APP_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/web/v0/cookies", action: "show" },
      { path: "http://#{CORE_APP_HOST}/web/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/web/v0/cookies", action: "update" },
      { path: "http://#{CORE_APP_HOST}/web/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/app/web/v0/themes", action: "show" },
      { path: "http://#{CORE_APP_HOST}/web/v0/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/web/v0/themes", action: "update" },
      { path: "http://#{CORE_APP_HOST}/web/v0/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/app/edge/v0/cookies", action: "show" },
      { path: "http://#{CORE_APP_HOST}/edge/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/edge/v0/cookies", action: "update" },
      { path: "http://#{CORE_APP_HOST}/edge/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/app/edge/v0/dbsc", action: "create" },
      { path: "http://#{CORE_APP_HOST}/edge/v0/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_APP_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_APP_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/auth/callbacks", action: "show", to: "/core/app/auth/callbacks#show" },
      { path: "http://#{CORE_APP_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/auth/authorizations", action: "show", to: "/core/app/auth/authorizations#show" },
      { path: "http://#{CORE_APP_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sign_outs", action: "new" },
      { path: "http://#{CORE_APP_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sign_outs", action: "edit" },
      { path: "http://#{CORE_APP_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/app/sign_outs", action: "create" },
      { path: "http://#{CORE_APP_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "core/app/sign_outs", action: "complete" },
      { path: "http://#{CORE_APP_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/app/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_APP_HOST}/oidc/backchannel/logout", method: :post },
    )
  end

  test "core com route contract" do
    assert_recognizes(
      { controller: "core/com/roots", action: "index" },
      { path: "http://#{CORE_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/well_known/jwks", action: "show" },
      { path: "http://#{CORE_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/healths", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/livenesses", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/readinesses", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/health/startups", action: "show" },
      { path: "http://#{CORE_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/robots", action: "index" },
      { path: "http://#{CORE_COM_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sitemaps", action: "show" },
      { path: "http://#{CORE_COM_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/web/v0/cookies", action: "show" },
      { path: "http://#{CORE_COM_HOST}/web/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/web/v0/cookies", action: "update" },
      { path: "http://#{CORE_COM_HOST}/web/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/com/web/v0/themes", action: "show" },
      { path: "http://#{CORE_COM_HOST}/web/v0/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/web/v0/themes", action: "update" },
      { path: "http://#{CORE_COM_HOST}/web/v0/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/com/edge/v0/cookies", action: "show" },
      { path: "http://#{CORE_COM_HOST}/edge/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/edge/v0/cookies", action: "update" },
      { path: "http://#{CORE_COM_HOST}/edge/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/com/edge/v0/dbsc", action: "create" },
      { path: "http://#{CORE_COM_HOST}/edge/v0/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_COM_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_COM_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/auth/callbacks", action: "show", to: "/core/com/auth/callbacks#show" },
      { path: "http://#{CORE_COM_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/auth/authorizations", action: "show", to: "/core/com/auth/authorizations#show" },
      { path: "http://#{CORE_COM_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sign_outs", action: "new" },
      { path: "http://#{CORE_COM_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sign_outs", action: "edit" },
      { path: "http://#{CORE_COM_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/com/sign_outs", action: "create" },
      { path: "http://#{CORE_COM_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "core/com/sign_outs", action: "complete" },
      { path: "http://#{CORE_COM_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_COM_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/com/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_COM_HOST}/oidc/backchannel/logout", method: :post },
    )
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "core org route contract" do
    assert_recognizes(
      { controller: "core/org/roots", action: "index" },
      { path: "http://#{CORE_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/well_known/jwks", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/healths", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/livenesses", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/readinesses", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/health/startups", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/robots", action: "index" },
      { path: "http://#{CORE_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sitemaps", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/csp_violation_reports", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/configurations", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/configuration", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/web/v0/cookies", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/web/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/web/v0/cookies", action: "update" },
      { path: "http://#{CORE_ORG_HOST}/web/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/org/web/v0/themes", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/web/v0/theme", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/web/v0/themes", action: "update" },
      { path: "http://#{CORE_ORG_HOST}/web/v0/theme", method: :patch },
    )

    assert_recognizes(
      { controller: "core/org/edge/v0/cookies", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/edge/v0/cookie", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/edge/v0/cookies", action: "update" },
      { path: "http://#{CORE_ORG_HOST}/edge/v0/cookie", method: :patch },
    )

    assert_recognizes(
      { controller: "core/org/edge/v0/dbsc", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/edge/v0/dbsc", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/sessions", action: "show" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/session", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/api/v0/token/refreshes", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/api/v0/token/refresh", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/auth/callbacks", action: "show", to: "/core/org/auth/callbacks#show" },
      { path: "http://#{CORE_ORG_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/auth/authorizations", action: "show", to: "/core/org/auth/authorizations#show" },
      { path: "http://#{CORE_ORG_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sign_outs", action: "new" },
      { path: "http://#{CORE_ORG_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sign_outs", action: "edit" },
      { path: "http://#{CORE_ORG_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "core/org/sign_outs", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "core/org/sign_outs", action: "complete" },
      { path: "http://#{CORE_ORG_HOST}/sign/out/complete", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/sso/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/auth/acme", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{CORE_ORG_HOST}/auth/acme/callback", method: :get)
    end

    assert_recognizes(
      { controller: "core/org/oidc/backchannel/logouts", action: "create" },
      { path: "http://#{CORE_ORG_HOST}/oidc/backchannel/logout", method: :post },
    )
  end
  # rubocop:enable Minitest/MultipleAssertions

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

  test "core rails remains transitional and does not expose authorization server endpoints" do
    [CORE_APP_HOST, CORE_COM_HOST, CORE_ORG_HOST, CORE_NET_HOST, CORE_DEV_HOST].each do |host|
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
