# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationEntraProviderAdapterTest < ActiveSupport::TestCase
  Connection = Data.define(:entra_tenant_id, :entra_client_id, :entra_client_secret)

  test "builds an authorization code request with PKCE and the approved scope" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
    )

    uri = URI.parse(adapter.authorization_url(state: "state", nonce: "nonce", code_challenge: "challenge"))
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "/11111111-2222-3333-4444-555555555555/oauth2/v2.0/authorize", uri.path
    assert_equal "code", query.fetch("response_type")
    assert_equal "openid profile", query.fetch("scope")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_not query.key?("offline_access")
    assert_not query.key?("email")
  end

  test "normalizes verified token evidence without retaining the token response" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    token_client =
      lambda do |**|
        OidcRpTokenClient::Result.new(success: true, token_response: { "id_token" => "discarded" }, error: nil)
      end
    verifier =
      Class.new do
        def initialize(**)
        end

        def call
          ExternalSignIn::NormalizedAuthResult.new(
            tenant_id: "11111111-2222-3333-4444-555555555555",
            entra_object_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            evidence_issuer: "https://login.microsoftonline.com/11111111-2222-3333-4444-555555555555/v2.0",
            evidence_subject: "pairwise-subject",
          )
        end
      end
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
      token_client: token_client,
      verifier_class: verifier,
    )

    result = adapter.call(code: "code", expected_nonce: "nonce", code_verifier: "verifier")

    assert_predicate result, :verified?
    assert_equal "entra", result.principal.provider
    assert_equal "pairwise-subject", result.principal.subject
    assert_equal "11111111-2222-3333-4444-555555555555", result.principal.tenant_context.tenant_id
    assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", result.principal.tenant_context.object_identifier
    assert_nil result.credential_candidate
  end

  test "maps token exchange failure to a safe typed result" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    token_client =
      lambda do |**|
        OidcRpTokenClient::Result.new(success: false, token_response: nil, error: "invalid_grant")
      end
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
      token_client: token_client,
    )

    result = adapter.call(code: "code", expected_nonce: "nonce", code_verifier: "verifier")

    assert_predicate result, :failed?
    assert_equal :token_exchange_failed, result.failure.code
    assert_equal :token_exchange_failed, result.failure.safe_reason
  end

  test "sends the ceremony PKCE verifier to the authorization-code exchange" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    token_client =
      lambda do |**arguments|
        assert_equal "pkce-verifier", arguments.fetch(:code_verifier)
        assert_equal "authorization-code", arguments.fetch(:code)
        OidcRpTokenClient::Result.new(success: false, token_response: nil, error: "invalid_grant")
      end
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
      token_client: token_client,
    )

    result = adapter.call(code: "authorization-code", expected_nonce: "nonce", code_verifier: "pkce-verifier")

    assert_equal :token_exchange_failed, result.failure.code
  end

  test "maps a tenant mismatch to a safe typed failure" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    token_client =
      lambda do |**|
        OidcRpTokenClient::Result.new(success: true, token_response: { "id_token" => "discarded" }, error: nil)
      end
    verifier =
      Class.new do
        def initialize(**)
        end

        def call
          raise ExternalSignIn::Providers::EntraId::VerificationError, "tid_mismatch"
        end
      end
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
      token_client: token_client,
      verifier_class: verifier,
    )

    result = adapter.call(code: "code", expected_nonce: "nonce", code_verifier: "verifier")

    assert_predicate result, :failed?
    assert_equal :tenant_mismatch, result.failure.code
    assert_equal :tenant_mismatch, result.failure.safe_reason
  end

  test "rejects a non-Entra principal before identity resolution" do
    connection = Connection.new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "client-id",
      entra_client_secret: "secret",
    )
    adapter = ExternalAuthentication::EntraProviderAdapter.new(
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "subject",
      issuer: "https://accounts.google.com",
      audience: "client-id",
      verified_at: Time.current,
      verification_authority: "test",
    )

    error =
      assert_raises(ArgumentError) do
        adapter.resolve_existing_identity(principal: principal)
      end

    assert_equal "Entra principal is required", error.message
  end
end
