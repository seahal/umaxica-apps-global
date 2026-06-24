# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "base.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
  end

  test "renders dashboard for signed-in operator" do
    get base_org_dashboard_url(ri: "jp"), headers: as_staff_headers(operators(:one), host: @host)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Base org signed-in landing/
    assert_select "a[href=?]", base_org_root_path(ri: "jp")
    assert_select "a[href=?]", base_org_dashboard_path(ri: "jp")
    assert_select "a[href=?]", base_org_settings_path(ri: "jp")
    assert_select "a[href=?]", new_base_org_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "redirects logged-out operator to acme authorize" do
    get base_org_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "base-rails-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end
end
