# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
  end

  test "show_renders_sign_dashboard" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Sign org signed-in landing/
    assert_select "a[href=?]", sign_org_root_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_in_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_up_path(ri: "jp")
    assert_select "a[href=?]", sign_org_settings_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_out_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_in_guard_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_in_check_path(ri: "jp")
    assert_select "a[href=?]", sign_org_sign_in_challenge_path(ri: "jp")
    assert_select "li", text: "Selector: handled by the sign-in guard sequence, no direct dashboard route"
    assert_no_match(/<a[^>]+>Selector<\/a>/, response.body)
    assert_no_match(%r{//example|umaxica\.example|evil\.example}, response.body)
  end

  test "show_redirects_when_logged_out" do
    get sign_org_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end
end
