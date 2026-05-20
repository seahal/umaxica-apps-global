# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Sign::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  include RootThemeCookieHelper

  setup do
    RateLimit.store.clear
  end

  teardown do
    RateLimit.store.clear
  end

  test "GET / redirects to new registration path" do
    get sign_app_root_url(ri: "jp")

    # Controller now renders the root index page with links to registration
    assert_response :success
    assert_select "h1", minimum: 1
  end

  test "GET / returns redirect status" do
    get sign_app_root_url(ri: "jp")

    assert_response :success
  end

  test "renders layout contract" do
    get sign_app_root_url(ri: "jp")

    assert_response :success
    assert_layout_contract
  end

  test "footer contains navigation links" do
    get sign_app_root_url(ri: "jp")

    assert_response :success
    assert_select "footer" do
      assert_select "a"
      assert_select "a[href=?]", sign_app_root_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.home")
      assert_select "a[href=?]", sign_app_preference_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.preference")
      assert_select "a[href=?]", sign_app_configuration_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.configuration")
    end
  end

  test "does not create preference records on root" do
    assert_no_difference("AppPreference.count") do
      get sign_app_root_url(ri: "jp")
    end

    assert_response :success
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: "id.app.localhost",
      path: :sign_app_root_path,
      label: "sign app root",
      ri: "jp",
    )
  end

  test "GET / redirects to dashboard when logged in" do
    user = clients(:one)
    get sign_app_root_url(ri: "jp"), headers: as_user_headers(user, host: "id.app.localhost")

    assert_redirected_to sign_app_dashboard_url(ri: "jp")
  end
end
