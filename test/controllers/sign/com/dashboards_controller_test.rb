# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    ApplicationRecord.clear_fixed_id_seed_cache!
    @visitor = create_verified_visitor_with_email(email_address: "dashboard-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+1000000#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "show redirects when not signed in" do
    get sign_com_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{/sign/in/new}, response.location
  end

  test "show renders when signed in" do
    get sign_com_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "a[href=?]", sign_com_configuration_path(ri: "jp")
    assert_select "footer" do
      assert_select "a[href=?]", sign_com_dashboard_url(ri: "jp"),
                    text: I18n.t("sign.com.preferences.footer.dashboard")
      assert_select "a[href=?]", sign_com_root_url(ri: "jp"),
                    text: I18n.t("sign.com.preferences.footer.home"),
                    count: 0
    end
  end
end
