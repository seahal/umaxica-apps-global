# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AuthOidcEntrancesTest < ActionDispatch::IntegrationTest
  setup do
    @sign_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    ClientIdentityState.ensure_defaults!
  end

  test "sign in entry accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_app_sign_in_url(login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @sign_host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "sign up entry accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    get auth_app_sign_up_url(login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @sign_host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "sign entry without login challenge normalizes to Acme authorize" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signin", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign up entry without login challenge normalizes to Acme authorize" do
    get auth_app_sign_up_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signup", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign started flow reaches Acme token exchange without stubbing OP" do
    with_sign_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      client = OidcClientRegistry.find!("sign-rp")

      get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @sign_host }

      assert_response :redirect
      authorize_uri = URI.parse(response.location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)
      code_verifier = session.fetch(:oidc_code_verifier)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path
      assert_not_equal "jump.umaxica.net", authorize_uri.host
      assert_equal "sign-rp", authorize_query["client_id"]

      host! acme_host
      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      assert_equal @sign_host, sign_uri.host
      assert_equal "/sign/in", sign_uri.path
      assert_predicate sign_query["login_challenge"], :present?

      host! @sign_host
      get sign_uri.request_uri, headers: browser_headers

      assert_response :success
      assert_equal sign_query["login_challenge"], session[:oidc_authorization_login_challenge]

      result =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: clients(:one),
          session_ref: "sign-e2e-session",
          auth_method: "passkey",
        )

      host! acme_host
      get URI.parse(result.resume_url).request_uri, headers: browser_headers

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal URI.parse(client.redirect_uris.first).host, callback_uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_equal authorize_query.fetch("state"), callback_query["state"]

      token_url = auth_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "sign-rp", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "sign-rp",
             code_verifier: code_verifier,
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: client_assertion,
           },
           headers: browser_headers

      assert_response :ok
      assert_predicate response.parsed_body["id_token"], :present?
      assert_predicate response.parsed_body["access_token"], :present?
    end
  end

  private

  def with_sign_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_SIGN_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_SIGN_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_SIGN_APP_ACTIVE_KID"] = "sign-app-oidc-test"
    ENV["OIDC_CLIENT_SIGN_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_SIGN_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_SIGN_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_SIGN_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_SIGN_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end

  def authorize_params(screen_hint: nil)
    params = {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
    params[:screen_hint] = screen_hint if screen_hint.present?
    params
  end
end
