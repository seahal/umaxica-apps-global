# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Auth::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  include RootThemeCookieHelper

  setup do
    host! ENV.fetch("AUTH_STAFF_URL")
  end

  test "GET / renders root page" do
    get auth_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Sign Org"
    assert_select "h1", text: "Sign Org"
  end

  test "creates preference cookies on root" do
    assert_difference("OrgPreference.count", 1) do
      get auth_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("AUTH_STAFF_URL"),
      path: :auth_org_root_path,
      label: "sign org root",
      ri: "jp",
    )
  end

  test "GET / redirects to dashboard when logged in" do
    staff = operators(:one)

    get auth_org_root_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("AUTH_STAFF_URL"))

    assert_response :redirect
    assert_redirected_to auth_org_dashboard_url(ri: "jp", host: ENV.fetch("AUTH_STAFF_URL"))
  end
end
