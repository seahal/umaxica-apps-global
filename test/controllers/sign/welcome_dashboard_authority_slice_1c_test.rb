# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  test "sign_welcome_redirects_to_acme_welcome" do
    get sign_app_welcome_entry_url(host: ENV.fetch("SIGN_SERVICE_URL"), ri: "jp")

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
    assert_equal "/welcome", location.path
    assert_equal "ri=jp", location.query
  end

  test "sign_dashboard_redirects_to_acme_dashboard" do
    get sign_app_dashboard_url(host: ENV.fetch("SIGN_SERVICE_URL"), ri: "jp")

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
    assert_equal "/dashboard", location.path
    assert_equal "ri=jp", location.query
  end

  test "acme_welcome_and_dashboard_routes_exist" do
    welcome = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/welcome",
      method: :get,
    )
    dashboard = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("ACME_SERVICE_URL")}/dashboard",
      method: :get,
    )

    assert_equal "acme/app/welcomes", welcome.fetch(:controller)
    assert_equal "show", welcome.fetch(:action)
    assert_equal "acme/app/dashboards", dashboard.fetch(:controller)
    assert_equal "show", dashboard.fetch(:action)
  end

  test "sign_welcome_and_dashboard_are_lightweight_redirect_only_controllers" do
    [
      Sign::App::WelcomesController,
      Sign::Com::WelcomesController,
      Sign::Org::WelcomesController,
      Sign::App::DashboardsController,
      Sign::Com::DashboardsController,
      Sign::Org::DashboardsController,
    ].each do |controller|
      assert_equal Sign::RedirectOnlyController, controller.superclass
      assert_not_includes controller.included_modules, Session
      assert_not_includes controller.included_modules, PreferenceGlobal
      assert_not_includes controller.included_modules, SessionLimitGate
      assert_not_includes controller.included_modules, RestrictedSessionGuard
    end
  end

  test "sign_in_and_sign_up_entry_routes_still_resolve_on_sign" do
    sign_in = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/in/entrance",
      method: :get,
    )
    sign_up = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/up/entrance",
      method: :get,
    )
    guard = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/up/guard/email",
      method: :get,
    )
    checkpoint = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_SERVICE_URL")}/sign/up/check/email/birthdate",
      method: :get,
    )

    assert_equal "sign/app/sign/in/entrances", sign_in.fetch(:controller)
    assert_equal "sign/app/sign/up/entrances", sign_up.fetch(:controller)
    assert_equal "sign/app/sign/up/guard/emails", guard.fetch(:controller)
    assert_equal "sign/app/sign/up/check/email/birthdates", checkpoint.fetch(:controller)
  end
end
