# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
  end

  test "show_redirects_to_acme_dashboard_authority" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_redirect_to_acme_dashboard
  end

  test "show_redirect_target_is_not_user_controlled" do
    get sign_app_dashboard_url(ri: "jp", return_to: "https://evil.example"),
        headers: as_user_headers(@user, host: @host)

    assert_redirect_to_acme_dashboard
  end

  private

  def assert_redirect_to_acme_dashboard
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/dashboard", location.path
    assert_equal "ri=jp", location.query
  end
end
