# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "acme-dashboard-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "dashboard_requires_authentication" do
    get acme_com_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    signin_uri = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal @host, signin_uri.host
    assert_equal "/oauth/authorize", signin_uri.path
  end

  test "dashboard_renders_when_signed_in" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    select_token!(surface: :com, principal: @visitor, token: token)

    get acme_com_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href=?]", acme_com_root_path(ri: "jp")
    assert_select "a[href=?]", acme_com_dashboard_path(ri: "jp")
    assert_select "a[href=?]", acme_com_selector_path(ri: "jp")
    assert_select "a[href=?]", edit_acme_com_sign_out_path(ri: "jp")
    assert_select "a[href=?]", acme_com_auth_authorization_path(ri: "jp", screen_hint: "signin")
    assert_select "a[href=?]", acme_com_auth_authorization_path(ri: "jp", screen_hint: "signup")
    assert_select "a[href=?]", acme_com_well_known_discovery_path
    assert_select "a[href=?]", acme_com_well_known_jwks_path
    assert_select "a[href=?]", acme_com_oauth_userinfo_path
    assert_no_match(%r{https?://|//example|id\.umaxica|umaxica\.example|evil\.example}, response.body)
  end

  test "welcome_route_exists" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/welcome",
      method: :get,
    )

    assert_equal "acme/com/welcomes", route.fetch(:controller)
  end

  private

  def select_token!(surface:, principal:, token:)
    AcmeSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    AcmeSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
