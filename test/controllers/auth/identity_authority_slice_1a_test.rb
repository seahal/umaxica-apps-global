# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  test "auth does not expose authorization-server authority routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/token",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/userinfo",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oidc/jwks",
        method: :get,
      )
    end
  end

  test "auth settings sessions route uses auth authority" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/settings/sessions",
      method: :get,
    )

    assert_equal "auth/app/settings/sessions", route.fetch(:controller)
    assert_equal "index", route.fetch(:action)
  end

  test "auth withdrawal resolves on auth settings authority" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/settings/withdrawal/new",
      method: :get,
    )

    assert_equal "auth/app/settings/withdrawals", route.fetch(:controller)
    assert_equal "new", route.fetch(:action)
  end

  test "auth sign in and sign up entry routes still resolve on auth" do
    sign_in = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/in",
      method: :get,
    )
    sign_up = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/up",
      method: :get,
    )

    assert_equal "auth/app/sign/ins", sign_in.fetch(:controller)
    assert_equal "show", sign_in.fetch(:action)
    assert_equal "auth/app/sign/ups", sign_up.fetch(:controller)
    assert_equal "show", sign_up.fetch(:action)
  end

  test "auth sign out lifecycle routes use the explicit ceremony contract" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/out/new",
      method: :get,
    )

    assert_equal "auth/app/sign/outs", route.fetch(:controller)
    assert_equal "new", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/out/edit",
      method: :get,
    )

    assert_equal "auth/app/sign/outs", route.fetch(:controller)
    assert_equal "edit", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/out",
      method: :post,
    )

    assert_equal "auth/app/sign/outs", route.fetch(:controller)
    assert_equal "create", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/out",
      method: :delete,
    )

    assert_equal "auth/app/sign/outs", route.fetch(:controller)
    assert_equal "destroy", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/sign/out/complete",
      method: :get,
    )

    assert_equal "auth/app/sign/outs", route.fetch(:controller)
    assert_equal "complete", route.fetch(:action)
  end

  test "acme authority owns logout and auth remains rp only" do
    sign_out = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")}/sign/out/new",
      method: :get,
    )
    oidc_logout = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")}/oidc/logout",
      method: :get,
    )
    sessions = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/settings/sessions",
      method: :get,
    )

    assert_equal "acme/app/sign/outs", sign_out.fetch(:controller)
    assert_equal "new", sign_out.fetch(:action)
    assert_equal "acme/app/oidc/logouts", oidc_logout.fetch(:controller)
    assert_equal "show", oidc_logout.fetch(:action)
    assert_equal "auth/app/settings/sessions", sessions.fetch(:controller)
    assert_equal "index", sessions.fetch(:action)

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oidc/logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end
