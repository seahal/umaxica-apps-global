# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
  end

  test "show redirects when not signed in" do
    get sign_app_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{\Ahttps://id\.umaxica\.app/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end

  test "show renders when signed in" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
    assert_select "footer" do
      assert_select "a[href=?]", sign_app_dashboard_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.dashboard")
      assert_select "a[href=?]", sign_app_root_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.home"),
                    count: 0
    end
  end
end
