# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  test "sign out lifecycle routes are retired from sign authority" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

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

  test "acme authority routes resolve for sign out while settings resolve on sign" do
    sign_out = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/sign/out",
      method: :get,
    )
    sessions = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/sessions",
      method: :get,
    )
    withdrawal = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/withdrawal",
      method: :patch,
    )

    assert_equal "sign/app/sign/outs", sign_out.fetch(:controller)
    assert_equal "show", sign_out.fetch(:action)
    assert_equal "sign/app/settings/sessions", sessions.fetch(:controller)
    assert_equal "index", sessions.fetch(:action)
    assert_equal "sign/app/settings/withdrawals", withdrawal.fetch(:controller)
    assert_equal "update", withdrawal.fetch(:action)
  end

  test "acme controllers own logout bridge primitive" do
    acme_sources = [
      Rails.root.join("app/controllers/acme/app/sign/outs_controller.rb"),
    ].map { |path| File.read(path) }.join("\n")

    assert_includes acme_sources, "OidcIdTokenIssuer.call"
    assert_includes acme_sources, "acme_app_oidc_logout_url"
  end
end
