# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("BASE_STAFF_URL")
    @staff = operators(:one)
  end

  test "dashboard_requires_authentication" do
    get base_org_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    signin_uri = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal @host, signin_uri.host
    assert_equal "/oauth/authorize", signin_uri.path
  end

  test "dashboard_renders_when_signed_in" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    get base_org_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href=?]", base_org_root_path(ri: "jp")
    assert_select "a[href=?]", base_org_dashboard_path(ri: "jp")
    assert_select "a[href=?]", base_org_account_path(ri: "jp"), text: "Account"
    assert_select "a[href=?]", base_org_current_organization_path(ri: "jp"), text: "Organization"
    assert_select "a[href=?]", base_org_avatar_path(ri: "jp"), text: "Avatar"
    assert_select "a[href=?]", base_org_selector_path(ri: "jp")
    assert_select "a[href=?]", new_base_org_sign_out_path(ri: "jp")
    assert_select "a[href=?]", base_org_oidc_authorization_path(ri: "jp", screen_hint: "signin")
    assert_select "a[href=?]", base_org_oidc_authorization_path(ri: "jp", screen_hint: "signup")
    assert_select "a", text: "OIDC discovery"
    assert_select "a", text: "JWKS"
    assert_select "a", text: "UserInfo"
    assert_no_match(%r{//example|umaxica\.example|evil\.example}, response.body)
  end

  test "welcome_route_exists" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/welcome",
      method: :get,
    )

    assert_equal "base/org/welcomes", route.fetch(:controller)
  end

  private

  def select_token!(surface:, principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
