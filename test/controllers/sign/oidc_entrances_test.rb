# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOidcEntrancesTest < ActionDispatch::IntegrationTest
  setup do
    @sign_host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  end

  test "sign in entrance accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionService.issue!(
      surface: "app",
      intent: "sign_in",
      params: authorize_params,
    )

    get sign_app_sign_in_entrance_url(login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @sign_host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "sign up entrance accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionService.issue!(
      surface: "app",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    get sign_app_sign_up_entrance_url(login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @sign_host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "sign entrance without login challenge does not seed oidc state" do
    get sign_app_sign_in_entrance_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :success
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign up entrance without login challenge does not seed oidc state" do
    get sign_app_sign_up_entrance_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :success
    assert_nil session[:oidc_authorization_login_challenge]
  end

  private

  def authorize_params(screen_hint: nil)
    params = {
      response_type: "code",
      client_id: "core_app",
      redirect_uri: OidcClientRegistry.find!("core_app").redirect_uris.first,
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
