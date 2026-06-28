# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Auth::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  include RootThemeCookieHelper

  setup do
    host! ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
  end

  test "GET / renders root page" do
    get auth_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Sign Com"
    assert_select "h1", text: "Sign Com"
  end

  test "creates preference cookies on root" do
    assert_difference("ComPreference.count", 1) do
      get auth_com_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost"),
      path: :auth_com_root_path,
      label: "sign com root",
      ri: "jp",
    )
  end

  test "GET / redirects to dashboard when logged in" do
    visitor = create_verified_visitor_with_email(email_address: "com-root-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002223",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get auth_com_root_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost"))

    assert_response :redirect
    assert_redirected_to auth_com_dashboard_url(ri: "jp", host: ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost"))
  end
end
