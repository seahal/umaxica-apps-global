# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("SIDE_SERVICE_URL")
    @acme_host = ENV.fetch("ACME_SERVICE_URL")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(@token)
  end

  test "renders dashboard for signed-in client" do
    get side_app_dashboard_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Side app signed-in landing/
    assert_select "a[href=?]", side_app_root_path(ri: "jp")
    assert_select "a[href=?]", side_app_dashboard_path(ri: "jp")
    assert_select "a[href=?]", side_app_settings_path(ri: "jp")
    assert_select "a[href=?]", new_side_app_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "forbids logged-out client" do
    get side_app_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_nil response.location
  end
end
