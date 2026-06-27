# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost")
    get base_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Base Com"
    assert_select "h1", text: "Base Com"
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost")

    assert_difference("ComPreference.count", 1) do
      get base_com_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end

  test "creates preference cookies on root when optional URL preferences are present" do
    host! ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost")

    assert_difference("ComPreference.count", 1) do
      get base_com_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end

  test "redirects to dashboard when logged in" do
    host! ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "base-com-root-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002226",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get base_com_root_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost"))

    assert_response :redirect
    assert_redirected_to base_com_dashboard_url(ri: "jp", host: ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost"))
  end
end
