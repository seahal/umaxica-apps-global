# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
  end

  test "show redirects when not signed in" do
    get sign_org_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{/sign/in/new}, response.location
  end

  test "show renders when signed in" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "a[href=?]", sign_org_configuration_path(ri: "jp")
  end
end
