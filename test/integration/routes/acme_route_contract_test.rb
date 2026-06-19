# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeRouteContractTest < ActionDispatch::IntegrationTest
  fixtures_none!

  ACME_APP_HOST = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  ACME_COM_HOST = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
  ACME_ORG_HOST = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

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
      { controller: "acme/app/sign_outs", action: "show" },
      { path: "http://#{ACME_APP_HOST}/sign/out", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/sign_outs", action: "create" },
      { path: "http://#{ACME_APP_HOST}/sign/out", method: :post },
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

    [
      { path: "/current/organization", method: :get },
      { path: "/current/organization/edit", method: :get },
      { path: "/current/organization", method: :patch },
      { path: "/current/avatar", method: :get },
      { path: "/current/avatar/edit", method: :get },
      { path: "/current/avatar", method: :patch },
      { path: "/current/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ACME_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    %w(show edit update destroy).each do |action|
      action_sym = action.to_sym
      method = (action_sym == :update) ? :patch : ((action_sym == :destroy) ? :delete : :get)
      path = (action_sym == :edit) ? "/avatar/edit" : "/avatar"

      assert_recognizes(
        { controller: "acme/app/avatars", action: action },
        { path: "http://#{ACME_APP_HOST}#{path}", method: },
      )
    end

    assert_recognizes(
      { controller: "acme/app/organizations", action: "show" },
      { path: "http://#{ACME_APP_HOST}/organization", method: :get },
    )

    {
      index: { path: "/organizations" },
      new: { path: "/organizations/new" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "acme/app/organizations", action: action.to_s },
        { path: "http://#{ACME_APP_HOST}#{opts[:path]}", method: :get },
      )
    end

    assert_recognizes(
      { controller: "acme/app/organizations", action: "show", id: "example" },
      { path: "http://#{ACME_APP_HOST}/organizations/example", method: :get, id: "example" },
    )

    assert_recognizes(
      { controller: "acme/app/organizations", action: "edit", id: "example" },
      { path: "http://#{ACME_APP_HOST}/organizations/example/edit", method: :get, id: "example" },
    )

    assert_recognizes(
      { controller: "acme/app/organizations", action: "create" },
      { path: "http://#{ACME_APP_HOST}/organizations", method: :post },
    )

    assert_recognizes(
      { controller: "acme/app/organizations", action: "update", id: "example" },
      { path: "http://#{ACME_APP_HOST}/organizations/example", method: :patch, id: "example" },
    )

    {
      index: { method: :get, path: "/organizations/example/memberships" },
      new: { method: :get, path: "/organizations/example/memberships/new" },
      create: { method: :post, path: "/organizations/example/memberships" },
      edit: { method: :get, path: "/organizations/example/memberships/member-example/edit", id: "member-example" },
      update: { method: :patch, path: "/organizations/example/memberships/member-example", id: "member-example" },
      destroy: { method: :delete, path: "/organizations/example/memberships/member-example", id: "member-example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "acme/app/organizations/memberships",
          action: action.to_s,
          organization_id: "example",
          id: opts[:id], }.compact,
        { path: "http://#{ACME_APP_HOST}#{opts[:path]}",
          method: opts[:method],
          organization_id: "example",
          id: opts[:id], }.compact,
      )
    end

    assert_recognizes(
      { controller: "acme/app/accounts", action: "show" },
      { path: "http://#{ACME_APP_HOST}/account", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/identities", action: "show" },
      { path: "http://#{ACME_APP_HOST}/identity", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/preferences", action: "show" },
      { path: "http://#{ACME_APP_HOST}/preference", method: :get },
    )

    {
      region: %w(edit patch),
      timezone: %w(edit patch),
      language: %w(edit patch),
      currency: %w(edit patch),
      calendar: %w(edit patch),
      clock: %w(edit patch),
      motion: %w(edit patch),
      density: %w(edit patch),
      pagination: %w(edit patch),
      theme: %w(edit patch),
      cookie: %w(edit patch),
    }.each do |name, (edit_action, _update_verb)|
      assert_recognizes(
        { controller: "acme/app/preference/#{name.to_s.pluralize}", action: edit_action },
        { path: "http://#{ACME_APP_HOST}/preference/#{name}/edit", method: :get },
      )

      assert_recognizes(
        { controller: "acme/app/preference/#{name.to_s.pluralize}", action: "update" },
        { path: "http://#{ACME_APP_HOST}/preference/#{name}", method: :patch },
      )
    end

    assert_recognizes(
      { controller: "acme/app/preference/resets", action: "edit" },
      { path: "http://#{ACME_APP_HOST}/preference/reset/edit", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/preference/resets", action: "destroy" },
      { path: "http://#{ACME_APP_HOST}/preference/reset", method: :delete },
    )

    assert_recognizes(
      { controller: "acme/app/preference/emails", action: "edit", id: "example" },
      { path: "http://#{ACME_APP_HOST}/preference/emails/example/edit", method: :get },
    )

    assert_recognizes(
      { controller: "acme/app/preference/emails", action: "destroy", id: "example" },
      { path: "http://#{ACME_APP_HOST}/preference/emails/example", method: :delete },
    )

    assert_recognizes(
      { controller: "acme/app/preference/emails", action: "create", id: "example" },
      { path: "http://#{ACME_APP_HOST}/preference/emails/example", method: :post },
    )

    %w(date time page_size).each do |name|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/preference/#{name}/edit", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/preference/#{name}", method: :patch)
      end
    end
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
      { controller: "acme/com/sign_outs", action: "show" },
      { path: "http://#{ACME_COM_HOST}/sign/out", method: :get },
    )

    assert_recognizes(
      { controller: "acme/com/sign_outs", action: "create" },
      { path: "http://#{ACME_COM_HOST}/sign/out", method: :post },
    )

    [
      { path: "/sso/authorize", method: :get },
      { path: "/sso/logout", method: :post },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ACME_COM_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
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

    [
      { path: "/current/organization", method: :get },
      { path: "/current/organization/edit", method: :get },
      { path: "/current/organization", method: :patch },
      { path: "/current/avatar", method: :get },
      { path: "/current/avatar/edit", method: :get },
      { path: "/current/avatar", method: :patch },
      { path: "/current/avatar", method: :delete },
      { path: "/avatar", method: :get },
      { path: "/avatar/edit", method: :get },
      { path: "/avatar", method: :patch },
      { path: "/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ACME_COM_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    {
      index: { path: "/organizations" },
      show: { path: "/organizations/example", id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "acme/com/organizations", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{ACME_COM_HOST}#{opts[:path]}", method: :get, id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "acme/com/organizations/memberships", action: "index", organization_id: "example" },
      { path: "http://#{ACME_COM_HOST}/organizations/example/memberships", method: :get, organization_id: "example" },
    )

    assert_recognizes(
      { controller: "acme/com/identities", action: "show" },
      { path: "http://#{ACME_COM_HOST}/identity", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_COM_HOST}/settings", method: :get)
    end
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
      { controller: "acme/org/sign_outs", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/sign/out", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/sign_outs", action: "create" },
      { path: "http://#{ACME_ORG_HOST}/sign/out", method: :post },
    )
  end

  test "acme org route contract (continued)" do
    [
      { path: "/sso/authorize", method: :get },
      { path: "/sso/logout", method: :post },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ACME_ORG_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
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

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/organization", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/organization/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/organization", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/avatar", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/avatar/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/avatar", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/current/avatar", method: :delete)
    end

    assert_recognizes(
      { controller: "acme/org/avatars", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/avatar", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/avatars", action: "edit" },
      { path: "http://#{ACME_ORG_HOST}/avatar/edit", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/avatars", action: "update" },
      { path: "http://#{ACME_ORG_HOST}/avatar", method: :patch },
    )

    assert_recognizes(
      { controller: "acme/org/avatars", action: "destroy" },
      { path: "http://#{ACME_ORG_HOST}/avatar", method: :delete },
    )

    assert_recognizes(
      { controller: "acme/org/organizations", action: "show" },
      { path: "http://#{ACME_ORG_HOST}/organization", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/organizations", action: "index" },
      { path: "http://#{ACME_ORG_HOST}/organizations", method: :get },
    )

    assert_recognizes(
      { controller: "acme/org/organizations/memberships",
        action: "destroy",
        organization_id: "example",
        id: "member-example", },
      { path: "http://#{ACME_ORG_HOST}/organizations/example/memberships/member-example",
        method: :delete,
        organization_id: "example",
        id: "member-example", },
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

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{ACME_ORG_HOST}/settings", method: :get)
    end
  end

  test "acme settings routes are retired" do
    {
      ACME_APP_HOST => "app",
      ACME_COM_HOST => "com",
      ACME_ORG_HOST => "org",
    }.each_key do |host|
      [
        { path: "/settings", method: :get },
        { path: "/settings/secrets", method: :get },
        { path: "/settings/secrets/enrollment", method: :post },
        { path: "/settings/secrets/secret-example/edit", method: :get },
        { path: "/settings/secrets/secret-example", method: :delete },
        { path: "/settings/secret_credentials", method: :get },
      ].each do |route|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{route.fetch(:path)}", method: route.fetch(:method))
        end
      end
    end
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
