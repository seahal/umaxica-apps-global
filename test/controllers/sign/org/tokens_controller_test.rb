# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::TokensControllerTest < ActionDispatch::IntegrationTest
  Result =
    Struct.new(:success, :token_response, :error, :error_description, keyword_init: true) do
      def success? = success
    end

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_org")
    @redirect_uri = @client.redirect_uris.first
    @client_secret = "test_secret_credential_for_core_org"
  end

  test "exchanges valid authorization code for tokens" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :ok
    body = response.parsed_body

    assert_predicate body["access_token"], :present?
    assert_predicate body["refresh_token"], :present?
    assert_equal "Bearer", body["token_type"]
    assert_kind_of Integer, body["expires_in"]

    payload = Authentication::TokenService.decode(
      body.fetch("access_token"),
      host: Oidc::Issuer.host_for_resource_type("operator"),
      resource_type: "operator",
      issuer: Oidc::Issuer.for_resource_type("operator"),
      audiences: [@client.aud],
      jwt_issuer_id: Oidc::Issuer.jwt_issuer_id_for_resource_type("operator"),
    )
    header = Jit::Security::Jwt::Keyring.parse_header(body.fetch("access_token"))
    acme_kids = Jit::Security::Jwt::Registry.jwks_for("surface:ACME_ORG").fetch(:keys).map { |key| key.fetch("kid") }

    assert_equal Oidc::Issuer.for_resource_type("operator"), payload.fetch("iss")
    assert_includes acme_kids, header.fetch("kid")
    assert_empty response.headers["Set-Cookie"].to_s,
                 "OAuth token compatibility must not create a browser session cookie"
  end

  test "sets no-store cache headers on success" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :ok
    assert_match(/no-store/, response.headers["Cache-Control"])
  end

  test "returns error for invalid grant_type" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
        grant_type: "implicit",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "returns error for nonexistent code" do
    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: "nonexistent_code",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_grant", body["error"]
  end

  test "returns error for wrong code_verifier" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
        code_verifier: "wrong_verifier",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "returns error for expired code" do
    code_record = issue_code!

    travel OperatorAuthorizationCode::CODE_TTL + 1.second do
      with_authenticated_client do
        post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
          code: code_record.code,
        ), headers: browser_headers
      end

      assert_response :bad_request
      body = response.parsed_body

      assert_equal "invalid_grant", body["error"]
    end
  end

  test "returns error for already consumed code" do
    code_record = issue_code!
    code_record.consume!

    with_authenticated_client do
      post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_grant", body["error"]
  end

  test "passes DPoP proof details to token exchange service" do
    code_record = issue_code!
    result = Result.new(success: true, token_response: { access_token: "access", refresh_token: "refresh" })
    captured = nil

    Oidc::TokenExchangeService.stub(
      :call,
      ->(**kwargs) do
        captured = kwargs
        result
      end,
    ) do
      with_authenticated_client do
        post sign_org_oauth_token_url(host: @host, ri: "jp"),
             params: token_params(code: code_record.code),
             headers: browser_headers.merge("DPoP" => "proof-jwt")
      end
    end

    assert_equal "proof-jwt", captured[:dpop_proof]
    assert_equal request.original_url, captured[:token_endpoint_uri]
    assert_equal "POST", captured[:request_method]
  end

  test "creates staff token record" do
    code_record = issue_code!

    assert_difference "OperatorToken.count", 1 do
      with_authenticated_client do
        post sign_org_oauth_token_url(host: @host, ri: "jp"), params: token_params(
          code: code_record.code,
        ), headers: browser_headers
      end
    end
  end

  private

  def token_params(code:, grant_type: "authorization_code", code_verifier: @code_verifier)
    {
      grant_type: grant_type,
      code: code,
      redirect_uri: @redirect_uri,
      client_id: "core_org",
      client_secret: @client_secret,
      code_verifier: code_verifier,
    }
  end

  def issue_code!
    OperatorAuthorizationCode.issue!(
      staff: @staff,
      client_id: "core_org",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "test_nonce",
    )
  end

  def with_authenticated_client(&block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_org" && sec == @client_secret
                     },
    ) do
      block.call
    end
  end
end
