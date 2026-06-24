# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  end

  test "renders dashboard for signed-in client" do
    get base_app_dashboard_url(ri: "jp"), headers: as_user_headers(clients(:one), host: @host)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Base app signed-in landing/
    assert_select "a[href=?]", base_app_root_path(ri: "jp")
    assert_select "a[href=?]", base_app_dashboard_path(ri: "jp")
    assert_select "a[href=?]", base_app_settings_path(ri: "jp")
    assert_select "a[href=?]", new_base_app_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "redirects logged-out client to acme authorize" do
    get base_app_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "base-rails-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end
end
