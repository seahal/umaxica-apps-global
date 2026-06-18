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

  test "sign settings sessions redirect uses acme authority" do
    get sign_app_settings_sessions_url(host: ENV.fetch("SIGN_SERVICE_URL"), ri: "jp")

    assert_response :see_other
    assert_equal ENV.fetch("ACME_SERVICE_URL"), URI.parse(response.location).host
    assert_equal "/settings/sessions", URI.parse(response.location).path
  end

  test "sign withdrawal delegates to acme identity authority" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/settings/withdrawal/new",
      method: :get,
    )
    source = Rails.root.join("app/controllers/sign/app/settings/withdrawals_controller.rb").read

    assert_equal "sign/app/settings/withdrawals", route.fetch(:controller)
    assert_includes source, "redirect_to_acme_withdrawal!"
    assert_includes source, 'redirect_to_acme_authority!("/settings/withdrawal")'
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

    assert_equal "sign/app/sign/sign_ins", sign_in.fetch(:controller)
    assert_equal "show", sign_in.fetch(:action)
    assert_equal "sign/app/sign/sign_ups", sign_up.fetch(:controller)
    assert_equal "show", sign_up.fetch(:action)
  end

  test "acme authority routes resolve for sign out sessions and withdrawal" do
    sign_out = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/sign/out",
      method: :delete,
    )
    sessions = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/settings/sessions/revoke_all",
      method: :delete,
    )
    withdrawal = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/settings/withdrawal",
      method: :patch,
    )

    assert_equal "acme/app/sign/outs", sign_out.fetch(:controller)
    assert_equal "destroy", sign_out.fetch(:action)
    assert_equal "acme/app/settings/sessions", sessions.fetch(:controller)
    assert_equal "revoke_all", sessions.fetch(:action)
    assert_equal "acme/app/settings/withdrawals", withdrawal.fetch(:controller)
    assert_equal "update", withdrawal.fetch(:action)
  end

  test "sign controllers keep withdrawal authority out of sign" do
    files = Rails.root.glob("app/controllers/sign/**/*.rb") +
      Rails.root.glob("app/controllers/concerns/sign_*.rb")
    forbidden = /WithdrawalLifecycle\./
    offenders =
      files.filter do |file|
        File.read(file).match?(forbidden)
      end

    assert_empty offenders, "sign controllers must not own withdrawal authority routes"
  end

  test "redirect only sign controllers avoid heavy sign application callback stack" do
    redirect_only_controllers = [
      Sign::App::Settings::SessionsController,
      Sign::Com::Settings::SessionsController,
      Sign::Org::Settings::SessionsController,
      Sign::Com::Settings::WithdrawalsController,
    ]

    redirect_only_controllers.each do |controller|
      assert_match(/::ApplicationController\z/, controller.superclass.name)
      assert_not_includes controller.included_modules, Session
      assert_not_includes controller.included_modules, PreferenceGlobal
      assert_not_includes controller.included_modules, SessionLimitGate
      assert_not_includes controller.included_modules, RestrictedSessionGuard
    end
  end

  test "acme controllers own logout session and withdrawal mutation primitives" do
    acme_sources = [
      Rails.root.join("app/controllers/acme/app/sign_outs_controller.rb"),
      Rails.root.join("app/controllers/acme/app/settings/sessions_controller.rb"),
      Rails.root.join("app/controllers/acme/app/settings/withdrawals_controller.rb"),
    ].map { |path| File.read(path) }.join("\n")

    assert_includes acme_sources, "logout_current_session!"
    assert_includes acme_sources, "AcmeSettingsSessionManagement"
    assert_includes acme_sources, "AcmeSettingsWithdrawalFlow"
  end
end
