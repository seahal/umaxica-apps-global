# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::TokenExchangeServiceTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_app")
    @redirect_uri = @client.redirect_uris.first
    @client_secret = "test_secret_credential_for_core_app"
  end

  test "exchanges valid code for tokens" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_predicate result.token_response[:id_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_kind_of Integer, result.token_response[:expires_in]
  end

  test "exchanges valid code with private_key_jwt client assertion" do
    code_record = issue_code!
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = Oidc::ClientAssertionJwt.issue(client_id: "core_app", token_url: token_url)

      result = Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core_app",
        client_assertion_type: Oidc::ClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: token_url,
      )

      assert_predicate result, :success?
      assert_predicate result.token_response[:id_token], :present?
    end
  end

  test "rejects private_key_jwt client assertion with wrong token endpoint audience" do
    code_record = issue_code!

    with_oidc_client_key("CORE_APP") do
      assertion = Oidc::ClientAssertionJwt.issue(
        client_id: "core_app",
        token_url: "https://id.umaxica.app/oauth/token",
      )

      result = Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core_app",
        client_assertion_type: Oidc::ClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: "https://id.umaxica.app/oauth/token-alt",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
    end
  end

  test "marks code as consumed after exchange" do
    code_record = issue_code!

    with_authenticated_client do
      Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core_app",
        client_secret: @client_secret,
        code_verifier: @code_verifier,
      )
    end

    code_record.reload

    assert_predicate code_record, :consumed?
  end

  test "fails for wrong grant_type" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "implicit",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for wrong client_secret_credential" do
    code_record = issue_code!

    # Do not stub authenticate; let it fail naturally with no secret_credential configured.
    result = Oidc::TokenExchangeService.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: @redirect_uri,
      client_id: "core_app",
      client_secret: "wrong_secret_credential",
      code_verifier: @code_verifier,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for nonexistent code" do
    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: "nonexistent_code",
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "fails for expired code" do
    code_record = issue_code!

    travel ClientAuthorizationCode::CODE_TTL + 1.second do
      result =
        with_authenticated_client do
          Oidc::TokenExchangeService.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core_app",
            client_secret: @client_secret,
            code_verifier: @code_verifier,
          )
        end

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end
  end

  test "fails for already consumed code" do
    code_record = issue_code!
    code_record.consume!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "fails for wrong redirect_uri" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: "http://wrong.host/callback",
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_not result.success?
  end

  test "fails for wrong code_verifier (PKCE)" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: "wrong_verifier_value",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for blank code_verifier" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: "",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "creates user token record" do
    code_record = issue_code!

    assert_difference "ClientToken.count", 1 do
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end
    end
  end

  test "records user RP connection and stamps issued token" do
    code_record = issue_code!(scope: "openid profile email")

    with_authenticated_client do
      Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core_app",
        client_secret: @client_secret,
        code_verifier: @code_verifier,
      )
    end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core_app")
    token = ClientToken.order(:created_at).last

    assert_equal "openid profile email", connection.scope
    assert_nil connection.revoked_at
    assert_equal connection.id, token.oidc_connection_id
    assert_equal "core_app", token.oidc_client_id
    assert_equal "openid profile email", token.oidc_scope
  end

  test "reactivates existing user RP connection on token exchange" do
    connection = ClientOidcConnection.create!(
      user: @user,
      client_id: "core_app",
      scope: "openid",
      last_used_at: 1.day.ago,
      revoked_at: 1.hour.ago,
    )
    code_record = issue_code!(scope: "openid email")

    with_authenticated_client do
      Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core_app",
        client_secret: @client_secret,
        code_verifier: @code_verifier,
      )
    end

    connection.reload

    assert_equal "openid email", connection.scope
    assert_nil connection.revoked_at
    assert_operator connection.last_used_at, :>, 1.minute.ago
  end

  test "refresh rotation preserves RP token linkage" do
    code_record = issue_code!(scope: "openid profile")

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core_app")
    previous_last_used_at = connection.last_used_at
    rotated = nil
    travel 1.minute do
      rotated = Sign::RefreshTokenService.call(refresh_token: result.token_response[:refresh_token])
    end
    replacement = rotated[:token]

    assert_equal connection.id, replacement.oidc_connection_id
    assert_equal "core_app", replacement.oidc_client_id
    assert_equal "openid profile", replacement.oidc_scope
    assert_operator connection.reload.last_used_at, :>, previous_last_used_at
  end

  # --- Operator OIDC token exchange tests ---

  test "exchanges valid operator code for tokens with OperatorToken" do
    staff = operators(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      client_id: "core_org",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
    )

    result =
      with_authenticated_org_client(staff_secret_credential) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core_org",
          client_secret: staff_secret_credential,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "creates staff token record for org client" do
    staff = operators(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      client_id: "core_org",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
    )

    assert_difference "OperatorToken.count", 1 do
      with_authenticated_org_client(staff_secret_credential) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core_org",
          client_secret: staff_secret_credential,
          code_verifier: @code_verifier,
        )
      end
    end
  end

  test "records staff RP connection" do
    staff = operators(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    staff_secret_credential = "test_secret_credential_for_core_org"
    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      client_id: "core_org",
      redirect_uri: org_client.redirect_uris.first,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
      scope: "openid staff",
    )

    with_authenticated_org_client(staff_secret_credential) do
      Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: org_client.redirect_uris.first,
        client_id: "core_org",
        client_secret: staff_secret_credential,
        code_verifier: @code_verifier,
      )
    end

    connection = OperatorOidcConnection.find_by!(staff_id: staff.id, client_id: "core_org")
    token = OperatorToken.order(:created_at).last

    assert_equal "openid staff", connection.scope
    assert_equal connection.id, token.oidc_connection_id
  end

  test "exchanges valid visitor code for tokens with VisitorToken" do
    visitor = create_visitor!
    com_client = Oidc::ClientRegistry.find("core_com")
    com_redirect_uri = com_client.redirect_uris.first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      client_id: "core_com",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
    )

    result =
      with_authenticated_com_client(visitor_secret_credential) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core_com",
          client_secret: visitor_secret_credential,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "creates visitor token record for com client" do
    visitor = create_visitor!
    com_client = Oidc::ClientRegistry.find("core_com")
    com_redirect_uri = com_client.redirect_uris.first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      client_id: "core_com",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
    )

    assert_difference "VisitorToken.count", 1 do
      with_authenticated_com_client(visitor_secret_credential) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core_com",
          client_secret: visitor_secret_credential,
          code_verifier: @code_verifier,
        )
      end
    end
  end

  test "records visitor RP connection" do
    visitor = create_visitor!
    com_client = Oidc::ClientRegistry.find("core_com")
    visitor_secret_credential = "test_secret_credential_for_core_com"
    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      client_id: "core_com",
      redirect_uri: com_client.redirect_uris.first,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
      scope: "openid visitor",
    )

    with_authenticated_com_client(visitor_secret_credential) do
      Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: com_client.redirect_uris.first,
        client_id: "core_com",
        client_secret: visitor_secret_credential,
        code_verifier: @code_verifier,
      )
    end

    connection = VisitorOidcConnection.find_by!(visitor_id: visitor.id, client_id: "core_com")
    token = VisitorToken.order(:created_at).last

    assert_equal "openid visitor", connection.scope
    assert_equal connection.id, token.oidc_connection_id
  end

  # --- DPoP token exchange tests ---

  test "issues DPoP-bound token when valid DPoP proof is provided" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    token_endpoint = "http://id.app.localhost/tokens"
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: token_endpoint)

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: token_endpoint,
          request_method: "POST",
        )
      end

    assert_predicate result, :success?
    assert_equal "DPoP", result.token_response[:token_type]
    assert_predicate result.token_response[:access_token], :present?

    token_record = ClientToken.last

    assert_predicate token_record.dpop_jkt, :present?
  end

  test "issues Bearer token when no DPoP proof is provided" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_nil ClientToken.last.dpop_jkt
  end

  test "fails when DPoP proof has wrong htm" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    token_endpoint = "http://id.app.localhost/tokens"
    proof = build_dpop_proof(private_key, jwk, method: "GET", uri: token_endpoint)

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: token_endpoint,
          request_method: "POST",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails when DPoP proof has wrong htu" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: "http://other.host/tokens")

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: "http://id.app.localhost/tokens",
          request_method: "POST",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "issues OIDC tokens with URL issuer public subject and split audiences" do
    code_record = issue_code!(scope: "openid profile")

    result =
      with_authenticated_client do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core_app",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?

    id_token = Oidc::IdTokenVerifier.call(
      id_token: result.token_response.fetch(:id_token),
      client_id: "core_app",
      resource_type: "client",
      expected_nonce: "test_nonce",
      issuer: Oidc::Issuer.for_client(@client),
      jwt_issuer_id: Oidc::Issuer.jwt_issuer_id_for_client(@client),
    )
    access_token = Authentication::TokenService.decode(
      result.token_response.fetch(:access_token),
      host: Oidc::Issuer.host_for_client(@client),
      resource_type: "client",
      issuer: Oidc::Issuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: Oidc::Issuer.jwt_issuer_id_for_client(@client),
    )

    assert_predicate id_token, :success?
    assert_equal Oidc::Issuer.for_client(@client), id_token.payload.fetch("iss")
    assert_equal Oidc::Subject.for(@user, resource_type: "client"), id_token.payload.fetch("sub")
    assert_equal "core_app", id_token.payload.fetch("aud")
    assert_equal Oidc::Issuer.for_client(@client), access_token.fetch("iss")
    assert_equal Oidc::Subject.for(@user, resource_type: "client"), access_token.fetch("sub")
    assert_equal [@client.aud], Array(access_token.fetch("aud"))
    assert_equal %w(openid profile), access_token.fetch("scp")
    assert_predicate access_token.fetch("auth_time"), :present?

    acme_kids = Jit::Security::Jwt::Registry.jwks_for("surface:ACME_APP").fetch(:keys).map { |key| key.fetch("kid") }
    access_header = Jit::Security::Jwt::Keyring.parse_header(result.token_response.fetch(:access_token))
    id_header = Jit::Security::Jwt::Keyring.parse_header(result.token_response.fetch(:id_token))

    assert_includes acme_kids, access_header.fetch("kid")
    assert_includes acme_kids, id_header.fetch("kid")
  end

  private

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:)
    payload = { "htm" => method, "htu" => uri, "iat" => Time.current.to_i, "jti" => SecureRandom.uuid }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end

  def issue_code!(scope: nil)
    ClientAuthorizationCode.issue!(
      user: @user,
      client_id: "core_app",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "test_nonce",
      scope: scope,
    )
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  # Stub ClientRegistry.authenticate to bypass secret_credential resolution in tests
  def with_authenticated_client(&block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_app" && sec == @client_secret
                     },
    ) do
      block.call
    end
  end

  def with_authenticated_org_client(secret_credential, &block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_org" && sec == secret_credential
                     },
    ) do
      block.call
    end
  end

  def with_authenticated_com_client(secret_credential, &block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_com" && sec == secret_credential
                     },
    ) do
      block.call
    end
  end

  def with_oidc_client_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = Jit::Security::Jwt::Registry.instance_variable_get(:@issuers)

    with_env(env) do
      Jit::Security::Jwt::Registry.reload!
      yield
    ensure
      Jit::Security::Jwt::Registry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
