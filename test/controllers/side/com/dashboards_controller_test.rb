# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::Com::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIDE_CORPORATE_URL", "side.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(
      email_address: "base-com-dashboard-#{SecureRandom.hex(4)}@example.com",
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
  end

  test "renders dashboard for signed-in visitor" do
    get side_com_dashboard_url(ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host, session_public_id: @token.public_id)

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Side com signed-in landing/
    assert_select "a[href=?]", side_com_root_path(ri: "jp")
    assert_select "a[href=?]", side_com_dashboard_path(ri: "jp")
    assert_select "a[href=?]", side_com_settings_path(ri: "jp")
    assert_select "a[href=?]", new_side_com_sign_out_path(ri: "jp")
    assert_no_match(%r{(?://example|evil\.example)}, response.body)
  end

  test "forbids logged-out visitor" do
    get side_com_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_nil response.location
  end
end
