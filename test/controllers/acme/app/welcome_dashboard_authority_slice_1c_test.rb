# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
  end

  test "dashboard_requires_authentication" do
    get acme_app_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    signin_uri = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal @host, signin_uri.host
    assert_equal "/oauth/authorize", signin_uri.path
  end

  test "dashboard_renders_when_signed_in" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get acme_app_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href=?]", acme_app_root_path(ri: "jp")
    assert_select "a[href=?]", acme_app_dashboard_path(ri: "jp")
    assert_select "a[href=?]", acme_app_selector_path(ri: "jp")
    assert_select "a[href=?]", edit_acme_app_sign_out_path(ri: "jp")
    assert_select "a[href=?]", acme_app_auth_authorization_path(ri: "jp", screen_hint: "signin")
    assert_select "a[href=?]", acme_app_auth_authorization_path(ri: "jp", screen_hint: "signup")
    assert_select "a[href=?]", acme_app_well_known_discovery_path
    assert_select "a[href=?]", acme_app_well_known_jwks_path
    assert_select "a[href=?]", acme_app_oauth_userinfo_path
    assert_no_match(%r{https?://|//example|id\.umaxica|umaxica\.example|evil\.example}, response.body)
  end

  test "shared dashboard render uses the surface-local authorization entrypoint" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get acme_app_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_select "a[href=?]", acme_app_auth_authorization_path(ri: "jp", screen_hint: "signin"),
                  text: "Authorize (sign in)"
    assert_select "a[href=?]", acme_app_auth_authorization_path(ri: "jp", screen_hint: "signup"),
                  text: "Authorize (sign up)"
  end

  test "welcome_requires_authentication" do
    get acme_app_welcome_entry_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  private

  def select_token!(surface:, principal:, token:)
    AcmeSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    AcmeSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
