# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignInsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "direct entry normalizes to acme org authorization" do
    get sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signin", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "valid login challenge renders local ceremony" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "local ceremony renders authentication links only" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success

    query = { ri: "jp" }

    assert_select "a[href=?]", new_sign_org_sign_in_passkey_path(query)
    assert_select "a[href=?]", new_sign_org_sign_in_secret_credential_path(query)
    assert_select "form[action*=?]", "/social/auth/", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/apple", count: 0
  end

  test "local ceremony ignores inbound pt and keeps authentication links on ceremony flow" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_org_sign_in_url(
      ri: "jp",
      pt: Base64.urlsafe_encode64("https://id.umaxica.org/settings/sessions?ri=jp", padding: false),
      login_challenge: issuance.transaction.login_challenge,
    ), headers: { "Host" => @host }

    assert_response :success
    assert_select "a[href=?]", new_sign_org_sign_in_passkey_path(ri: "jp")
    assert_select "a[href=?]", new_sign_org_sign_in_secret_credential_path(ri: "jp")
  end

  test "local ceremony does not render sign up link on sign in page" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_select "a[href=?]", sign_org_sign_up_path(ri: "jp"), count: 0
  end

  test "local ceremony renders back to root link" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success

    assert_select "a[href=?]", acme_org_root_url(ri: "jp", host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
  end

  test "rejects direct entry when logged in" do
    staff = operators(:one)

    get sign_org_sign_in_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  private

  def authorize_params
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
end
