# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
  end

  test "show redirects when not signed in" do
    get sign_org_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end

  test "show renders when signed in" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "a[href=?]", sign_org_settings_path(ri: "jp")
    assert_select "footer" do
      assert_select "a[href=?]", sign_org_dashboard_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.dashboard")
      assert_select "a[href=?]", sign_org_root_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.home"),
                    count: 0
    end
  end
end
