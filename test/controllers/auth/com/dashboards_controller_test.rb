# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "dashboard-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
  end

  test "show_renders_sign_dashboard" do
    get auth_com_dashboard_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /Sign com signed-in landing/
    assert_select "a[href=?]", auth_com_root_path(ri: "jp")
    assert_select "a[href=?]", auth_com_sign_in_path(ri: "jp")
    assert_select "a[href=?]", auth_com_sign_up_path(ri: "jp")
    assert_select "a[href=?]", auth_com_settings_path(ri: "jp")
    assert_select "a[href=?]", new_auth_com_sign_out_path(ri: "jp")
    assert_select "a[href=?]", auth_com_sign_in_guard_path(ri: "jp")
    assert_select "a[href=?]", auth_com_sign_in_check_path(ri: "jp")
    assert_select "a[href=?]", auth_com_sign_in_challenge_path(ri: "jp")
    assert_select "li", text: "Selector: handled by the sign-in guard sequence, no direct dashboard route"
    assert_no_match(/<a[^>]+>Selector<\/a>/, response.body)
    assert_no_match(%r{(?://example|umaxica\.example|evil\.example)}, response.body)
  end

  test "show_redirects_when_logged_out" do
    get auth_com_dashboard_url(ri: "jp"), headers: { "Host" => @host }

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal @acme_host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "code", query["response_type"]
  end

  private

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
