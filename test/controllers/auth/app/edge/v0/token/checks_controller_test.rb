# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/auth_helpers"

class Auth::App::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @user = clients(:one)
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    ClientToken.where(user: @user).delete_all
  end

  test "GET check with valid JWT access token returns 200" do
    # Create a token record and generate tokens
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Client should be authenticated"
    assert_equal "client", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end

  # DBSC registration is offered to authenticated sessions that are not yet device-bound. This is
  # the response the `script/dbsc_probe` registration check targets, and the header Chromium reads
  # to start a DBSC session. A non-DBSC token must therefore receive `Secure-Session-Registration`
  # (and its legacy `Sec-Session-Registration` alias) pointing at the DBSC refresh endpoint.
  test "GET check offers Secure-Session-Registration to a non-DBSC-bound session" do
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    assert_not token_record.binding_method_dbsc?,
               "fresh token must not be DBSC-bound for this registration-offer assertion"

    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok

    registration = response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]
    legacy_registration = response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION]

    assert_predicate registration, :present?, "expected Secure-Session-Registration on check response"
    assert_equal registration, legacy_registration
    assert_includes registration, "(ES256 RS256);"
    assert_includes registration, %(path="#{sign_app_edge_v0_token_dbsc_path}")
    assert_includes registration, "challenge="
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

  test "GET check with invalid JWT returns 401" do
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "invalid.jwt.token"

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with expired JWT returns 401" do
    # Create a token record
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT that's already expired
    # We need to manipulate time to create an expired token
    expired_token = nil
    travel_to(2.hours.ago) do
      expired_token = jwt_access_token_for(
        @user,
        host: @host,
        session_public_id: token_record.public_id,
        resource_type: "client",
      )
    end

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = expired_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with wrong resource type returns 401" do
    # Create a token record
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT with wrong resource type (operator instead of user)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "operator", # wrong type for user endpoint
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check includes Cache-Control no-store header" do
    token_record = ClientToken.create!(user: @user)
    access_token = jwt_access_token_for(
      @user, host: @host, session_public_id: token_record.public_id,
             resource_type: "client",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :success

    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "GET check with Bearer header takes precedence over cookie" do
    # Create a token record and generate tokens
    token_record = ClientToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    # Set invalid cookie but valid Bearer header
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "invalid.cookie.token"

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Bearer token should take precedence"
    assert_equal "client", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end

  test "GET check accepts DPoP-bound token with valid proof" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    token_record.update!(dpop_jkt: jkt)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
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

  test "GET check rejects DPoP-bound token presented as Bearer" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
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
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects DPoP-bound token without proof" do
    token_record = ClientToken.create!(user: @user)
    _private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
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
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects DPoP proof with wrong ath" do
    token_record = ClientToken.create!(user: @user)
    private_key, jwk = generate_dpop_jwk
    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
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
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check rejects when access token cnf jkt differs from stored token JKT" do
    token_record = ClientToken.create!(user: @user)
    _stored_key, stored_jwk = generate_dpop_jwk
    proof_key, proof_jwk = generate_dpop_jwk
    stored_jkt = JitSecurityJwtThumbprintCalculator.calculate(stored_jwk)
    proof_jkt = JitSecurityJwtThumbprintCalculator.calculate(proof_jwk)
    token_record.update!(dpop_jkt: stored_jkt)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      dpop_jkt: proof_jkt,
    )
    proof = build_dpop_proof(
      proof_key, proof_jwk, method: "GET", uri: "http://#{@host}/edge/v0/token/check",
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

    assert_response :unauthorized
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "GET check with missing sid returns 401" do
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: nil,
      resource_type: "client",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
  end

  test "logout destroys token record so old Bearer access fails" do
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    # Verify token exists before logout
    assert_not_nil ClientToken.find_by(public_id: token_record.public_id)

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
    assert_equal "セッションの有効期限が切れました。もう一度サインインしてください。", response.body
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
end
