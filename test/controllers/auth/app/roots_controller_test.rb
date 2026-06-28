# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Auth::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  include RootThemeCookieHelper

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "renders a thin landing page" do
    get auth_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Sign App"
    assert_select "h1", text: "Sign App"
    assert_select "main p", text: /Thin landing endpoint/
  end

  test "creates preference cookies on root" do
    assert_difference("AppPreference.count", 1) do
      get auth_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      path: :auth_app_root_path,
      label: "sign app root",
      ri: "jp",
    )
  end

  test "GET / redirects to dashboard when logged in" do
    user = clients(:one)
    get auth_app_root_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))

    assert_response :redirect
    assert_redirected_to auth_app_dashboard_url(
      ri: "jp",
      host: ENV.fetch(
        "PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost",
      ),
    )
  end
end
