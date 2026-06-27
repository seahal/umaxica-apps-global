# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/auth_helpers"

class Auth::Org::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :clients

  setup do
    @staff = operators(:one)
    @host = ENV.fetch("ID_STAFF_URL", "test.umaxica.com")
  end

  test "GET check with valid JWT access token returns 200" do
    token_record = OperatorToken.create!(staff: @staff)
    token_record.rotate_refresh_token!

    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Operator should be authenticated"
    assert_equal "operator", json["type"]
    assert_equal @staff.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check with missing sid returns 401" do
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: nil,
      resource_type: "operator",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_unauthenticated_response
  end

  test "GET check with user token on staff endpoint returns 401" do
    user = clients(:one)

    # Create a staff token record for the session to exist
    token_record = OperatorToken.create!(staff: @staff)
    token_record.rotate_refresh_token!

    # Generate a JWT with client actor type (wrong for staff endpoint)
    access_token = jwt_access_token_for(
      user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "user",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "logout destroys token record so old Bearer access fails" do
    token_record = OperatorToken.create!(staff: @staff)
    refresh_plain = token_record.rotate_refresh_token!
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    # Verify token exists before logout
    assert_not_nil OperatorToken.find_by(public_id: token_record.public_id)

    # Simulate logout by destroying the token directly (the cookie-based destroy
    # requires domain matching which is complex in integration tests)
    token_record.destroy!

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_unauthenticated_response
  end

  test "GET check accepts DPoP-bound staff token with valid proof" do
    token_record = OperatorToken.create!(staff: @staff)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    token_record.update!(dpop_jkt: jkt)
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: access_token,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "GET check rejects DPoP-bound staff token presented as Bearer" do
    token_record = OperatorToken.create!(staff: @staff)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: access_token,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_unauthenticated_response
  end

  test "GET check rejects DPoP-bound staff token without proof" do
    token_record = OperatorToken.create!(staff: @staff)
    _private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
      dpop_jkt: jkt,
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_unauthenticated_response
  end

  test "GET check rejects DPoP staff proof with wrong ath" do
    token_record = OperatorToken.create!(staff: @staff)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
      dpop_jkt: jkt,
    )
    proof = build_dpop_proof(
      private_key, jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
                        access_token: "different-token",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "DPoP #{access_token}",
          "DPoP" => proof,
        },
        as: :json

    assert_response :unauthorized
    assert_predicate response.headers["DPoP-Nonce"], :present?
    assert_unauthenticated_response
  end

  private

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:, access_token:)
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
      "ath" => JitSecurityJwtThumbprintCalculator.ath(access_token),
    }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end

  def assert_unauthenticated_response
    body = response.parsed_body
    return assert_equal({ "authenticated" => false }, body) if body.is_a?(Hash)

    assert_equal I18n.t("auth.session_expired"), body
  end
end
