# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  test "sign settings sessions route uses sign authority" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/sessions",
      method: :get,
    )

    assert_equal "sign/app/settings/sessions", route.fetch(:controller)
    assert_equal "index", route.fetch(:action)
  end

  test "sign withdrawal resolves on sign settings authority" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/withdrawal/new",
      method: :get,
    )

    assert_equal "sign/app/settings/withdrawals", route.fetch(:controller)
    assert_equal "new", route.fetch(:action)
  end

  test "sign in and sign up entry routes still resolve on sign" do
    sign_in = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/in",
      method: :get,
    )
    sign_up = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/up",
      method: :get,
    )

    assert_equal "sign/app/sign/ins", sign_in.fetch(:controller)
    assert_equal "show", sign_in.fetch(:action)
    assert_equal "sign/app/sign/ups", sign_up.fetch(:controller)
    assert_equal "show", sign_up.fetch(:action)
  end

  test "sign out lifecycle routes use the explicit ceremony contract" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/out/new",
      method: :get,
    )

    assert_equal "sign/app/sign/outs", route.fetch(:controller)
    assert_equal "new", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/out/edit",
      method: :get,
    )

    assert_equal "sign/app/sign/outs", route.fetch(:controller)
    assert_equal "edit", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/out",
      method: :post,
    )

    assert_equal "sign/app/sign/outs", route.fetch(:controller)
    assert_equal "create", route.fetch(:action)

    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/out/complete",
      method: :get,
    )

    assert_equal "sign/app/sign/outs", route.fetch(:controller)
    assert_equal "complete", route.fetch(:action)
  end

  test "acme authority owns logout and sign authority does not expose oidc logout" do
    sign_out = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/sign/out/new",
      method: :get,
    )
    oidc_logout = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/oidc/logout",
      method: :get,
    )
    sessions = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/sessions",
      method: :get,
    )

    assert_equal "acme/app/sign/outs", sign_out.fetch(:controller)
    assert_equal "new", sign_out.fetch(:action)
    assert_equal "acme/app/oidc/logouts", oidc_logout.fetch(:controller)
    assert_equal "show", oidc_logout.fetch(:action)
    assert_equal "sign/app/settings/sessions", sessions.fetch(:controller)
    assert_equal "index", sessions.fetch(:action)

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("SIGN_SERVICE_URL")}/oidc/logout",
        method: :get,
      )
    end
  end
end
