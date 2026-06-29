# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class BaseRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL")

  # rubocop:disable Minitest/MultipleAssertions
  test "base app route contract" do
    [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, "www.umaxica.app",
     BASE_APP_HOST,].uniq.each do |host|
      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/",
        method: :get,
      )

      assert_equal "base/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health",
        method: :get,
      )

      assert_equal "base/app/healths", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/liveness",
        method: :get,
      )

      assert_equal "base/app/health/livenesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/readiness",
        method: :get,
      )

      assert_equal "base/app/health/readinesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/startup",
        method: :get,
      )

      assert_equal "base/app/health/startups", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/robots.txt",
        method: :get,
      )

      assert_equal "base/app/robots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sitemap.xml",
        method: :get,
      )

      assert_equal "base/app/sitemaps", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/identity/emails",
        method: :get,
      )

      assert_equal "base/app/identity/emails", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/groups",
        method: :get,
      )

      assert_equal "base/app/groups", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/dashboard",
        method: :get,
      )

      assert_equal "base/app/dashboards", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oidc/authorization",
        method: :get,
      )

      assert_equal "base/app/auth/authorizations", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/oidc/callback",
        method: :get,
      )

      assert_equal "base/app/auth/callbacks", recognized[:controller]
      assert_equal "show", recognized[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oidc", method: :get)
      end

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sign/out/new",
        method: :get,
      )

      assert_equal "base/app/sign/outs", recognized[:controller]
      assert_equal "new", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sign/out",
        method: :post,
      )

      assert_equal "base/app/sign/outs", recognized[:controller]
      assert_equal "create", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sign/out/complete",
        method: :get,
      )

      assert_equal "base/app/sign/outs", recognized[:controller]
      assert_equal "complete", recognized[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/sign/out", method: :delete)
      end

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/csp-violation-report",
        method: :post,
      )

      assert_equal "base/app/csp_violation_reports", recognized[:controller]
      assert_equal "create", recognized[:action]
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
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
      "http://#{BASE_COM_HOST}/dashboard",
      method: :get,
    )

    assert_equal "base/com/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/com/auth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/oidc/callback",
      method: :get,
    )

    assert_equal "base/com/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out/new",
      method: :get,
    )

    assert_equal "base/com/sign/outs", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out/edit",
      method: :get,
    )

    assert_equal "base/com/sign/outs", recognized[:controller]
    assert_equal "edit", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/com/sign/outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/sign/out/complete",
      method: :get,
    )

    assert_equal "base/com/sign/outs", recognized[:controller]
    assert_equal "complete", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out", method: :delete)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
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
      "http://#{BASE_ORG_HOST}/dashboard",
      method: :get,
    )

    assert_equal "base/org/dashboards", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/oidc/authorization",
      method: :get,
    )

    assert_equal "base/org/auth/authorizations", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/oidc/callback",
      method: :get,
    )

    assert_equal "base/org/auth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc", method: :get)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out/new",
      method: :get,
    )

    assert_equal "base/org/sign/outs", recognized[:controller]
    assert_equal "new", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out/edit",
      method: :get,
    )

    assert_equal "base/org/sign/outs", recognized[:controller]
    assert_equal "edit", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out",
      method: :post,
    )

    assert_equal "base/org/sign/outs", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sign/out/complete",
      method: :get,
    )

    assert_equal "base/org/sign/outs", recognized[:controller]
    assert_equal "complete", recognized[:action]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out", method: :delete)
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end
  # rubocop:enable Minitest/MultipleAssertions
end
