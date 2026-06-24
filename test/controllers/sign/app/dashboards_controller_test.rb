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

  test "show_renders_sign_dashboard" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Sign app signed-in landing/
    assert_select "a[href=?]", sign_app_root_path(ri: "jp")
    assert_select "a[href=?]", sign_app_sign_in_path(ri: "jp")
    assert_select "a[href=?]", sign_app_sign_up_path(ri: "jp")
    assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
    assert_select "a[href=?]", new_sign_app_sign_out_path(ri: "jp")
    assert_select "a[href=?]", sign_app_sign_in_guard_path(ri: "jp")
    assert_select "a[href=?]", sign_app_sign_in_check_path(ri: "jp")
    assert_select "a[href=?]", sign_app_sign_in_challenge_path(ri: "jp")
    assert_select "a[href=?]", new_sign_app_sign_in_challenge_totp_path(ri: "jp")
    assert_select "a[href=?]", sign_app_verification_path(ri: "jp")
    assert_select "a[href=?]", new_sign_app_verification_totp_path(ri: "jp")
    assert_select "li", text: "Selector: handled by the sign-in guard sequence, no direct dashboard route"
    assert_no_match(/<a[^>]+>Selector<\/a>/, response.body)
    assert_no_match(%r{//example|id\.umaxica|umaxica\.example|evil\.example}, response.body)
  end

  test "show_redirects_when_logged_out" do
    get sign_app_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end

  test "show_ignores_user_controlled_return_to" do
    get sign_app_dashboard_url(ri: "jp", return_to: "https://evil.example"),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
  end
end
