# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::TokenExchangeServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_app")
    @redirect_uri = @client.redirect_uris.first
    @client_secret = "test_secret_for_core_app"
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
    assert_equal "Bearer", result.token_response[:token_type]
    assert_kind_of Integer, result.token_response[:expires_in]
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

  test "fails for wrong client_secret" do
    code_record = issue_code!

    # Do not stub authenticate; let it fail naturally with no secret configured.
    result = Oidc::TokenExchangeService.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: @redirect_uri,
      client_id: "core_app",
      client_secret: "wrong_secret",
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

    travel UserAuthorizationCode::CODE_TTL + 1.second do
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

    assert_difference "UserToken.count", 1 do
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

  # --- Operator OIDC token exchange tests ---

  test "exchanges valid operator code for tokens with OperatorToken" do
    staff = staffs(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first
    staff_secret = "test_secret_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      client_id: "core_org",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )

    result =
      with_authenticated_org_client(staff_secret) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core_org",
          client_secret: staff_secret,
          code_verifier: @code_verifier,
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "creates staff token record for org client" do
    staff = staffs(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first
    staff_secret = "test_secret_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      client_id: "core_org",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )

    assert_difference "OperatorToken.count", 1 do
      with_authenticated_org_client(staff_secret) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core_org",
          client_secret: staff_secret,
          code_verifier: @code_verifier,
        )
      end
    end
  end

  test "exchanges valid visitor code for tokens with VisitorToken" do
    visitor = create_visitor!
    com_client = Oidc::ClientRegistry.find("core_com")
    com_redirect_uri = com_client.redirect_uris.first
    visitor_secret = "test_secret_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      client_id: "core_com",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )

    result =
      with_authenticated_com_client(visitor_secret) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core_com",
          client_secret: visitor_secret,
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
    visitor_secret = "test_secret_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      client_id: "core_com",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )

    assert_difference "VisitorToken.count", 1 do
      with_authenticated_com_client(visitor_secret) do
        Oidc::TokenExchangeService.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core_com",
          client_secret: visitor_secret,
          code_verifier: @code_verifier,
        )
      end
    end
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

    token_record = UserToken.last

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
    assert_nil UserToken.last.dpop_jkt
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

  def issue_code!
    UserAuthorizationCode.issue!(
      user: @user,
      client_id: "core_app",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMultiFactor.find_or_create_by!(id: VisitorMultiFactor::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  # Stub ClientRegistry.authenticate to bypass secret resolution in tests
  def with_authenticated_client(&block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_app" && sec == @client_secret
                     },
    ) do
      block.call
    end
  end

  def with_authenticated_org_client(secret, &block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_org" && sec == secret
                     },
    ) do
      block.call
    end
  end

  def with_authenticated_com_client(secret, &block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_com" && sec == secret
                     },
    ) do
      block.call
    end
  end
end
