# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  test "should get index" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    get acme_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Acme Org"
    assert_select "h1", text: "Acme Org"
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

    assert_difference("OrgPreference.count", 1) do
      get acme_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end

  test "creates preference cookies on root when optional URL preferences are present" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

    assert_difference("OrgPreference.count", 1) do
      get acme_org_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end

  test "redirects to dashboard when logged in" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)

    get acme_org_root_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))

    assert_response :redirect
    assert_redirected_to acme_org_dashboard_url(ri: "jp", host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
  end
end
