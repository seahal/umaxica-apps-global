# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Sign::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  include RootThemeCookieHelper

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "renders a thin landing page" do
    get sign_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Sign App"
    assert_select "h1", text: "Sign App"
    assert_select "main p", text: /Thin landing endpoint/
  end

  test "creates preference cookies on root" do
    assert_difference("AppPreference.count", 1) do
      get sign_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      path: :sign_app_root_path,
      label: "sign app root",
      ri: "jp",
    )
  end

  test "GET / redirects to dashboard when logged in" do
    user = clients(:one)
    get sign_app_root_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :redirect
    assert_redirected_to sign_app_dashboard_url(ri: "jp", host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end
end
