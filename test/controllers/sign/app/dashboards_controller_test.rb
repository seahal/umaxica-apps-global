# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @user.update!(status_id: UserStatus::ACTIVE)
  end

  test "show redirects when not signed in" do
    get sign_app_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{/sign/in/new}, response.location
  end

  test "show renders when signed in" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end
end
