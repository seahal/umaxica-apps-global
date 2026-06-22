# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
  end

  test "renders anonymous root" do
    host! @host

    get base_app_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Base App"
  end

  test "redirects signed-in client to dashboard" do
    host! @host

    get base_app_root_url(ri: "jp"), headers: as_user_headers(clients(:one), host: @host)

    assert_response :redirect
    assert_redirected_to base_app_dashboard_url(ri: "jp", host: @host)
  end
end
