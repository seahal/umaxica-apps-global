# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "base-com-dashboard-#{SecureRandom.hex(4)}@example.com")
  end

  test "renders dashboard for signed-in visitor" do
    get base_com_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Base com signed-in landing/
    assert_select "a[href=?]", base_com_root_path(ri: "jp")
    assert_select "a[href=?]", base_com_dashboard_path(ri: "jp")
    assert_select "a[href=?]", base_com_settings_path(ri: "jp")
    assert_select "a[href=?]", new_base_com_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "redirects logged-out visitor to acme authorize" do
    get base_com_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "base-rails-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end
end
