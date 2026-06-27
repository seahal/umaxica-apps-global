# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("SIDE_STAFF_URL", "side.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @operator = operators(:one)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(@token)
  end

  test "renders dashboard for signed-in operator" do
    get side_org_dashboard_url(ri: "jp"),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Side org signed-in landing/
    assert_select "a[href=?]", side_org_root_path(ri: "jp")
    assert_select "a[href=?]", side_org_dashboard_path(ri: "jp")
    assert_select "a[href=?]", side_org_settings_path(ri: "jp")
    assert_select "a[href=?]", new_side_org_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "forbids logged-out operator" do
    get side_org_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_nil response.location
  end
end
