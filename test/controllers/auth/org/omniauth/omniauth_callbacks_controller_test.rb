# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Omniauth::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Other suites (e.g. test/integration/social_auth_login_test.rb) set
    # OmniAuth.config.test_mode = true and never restore it. Left on, OmniAuth
    # short-circuits the request phase into a mocked callback, so the real
    # strategy under test here never runs.
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "entra-omniauth-callback-test-client",
      entra_credential_key: "entra-omniauth-callback-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
  end

  test "GET /social/entra/session/new is routable and renders the start form for an active connection" do
    get new_auth_org_social_entra_session_path(connection: @connection.public_id, ri: "jp")

    assert_response :success
  end

  test "POST /social/entra with an unknown connection fails closed via the strategy request phase" do
    post "/social/entra", params: { connection_public_id: "does-not-exist" }

    assert_response :found
    assert_match %r{\A/social/entra/failure}, response.location
  end

  test "POST /social/entra with an active connection redirects to the tenant-fixed Microsoft authorize endpoint" do
    post "/social/entra", params: { connection_public_id: @connection.public_id }

    assert_response :found
    uri = URI.parse(response.location)

    assert_equal "login.microsoftonline.com", uri.host
    assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", uri.path

    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "openid profile", query.fetch("scope")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_not_includes uri.query, "common"
    assert_not_includes uri.query, "organizations"
  end

  test "full round trip: request phase then callback establishes an operator session for a pre-provisioned identity" do
    operator = operators(:one)
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      connection_id: @connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    post "/social/entra", params: { connection_public_id: @connection.public_id }

    assert_response :found
    authorize_uri = URI.parse(response.location)
    authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-round-trip" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => @connection.entra_client_id,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-round-trip" },
    )

    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :redirect
    assert_not response.location.to_s.include?("/social/entra/failure")
  end

  test "callback fails closed when no OperatorEntraIdentity is provisioned (no JIT)" do
    post "/social/entra", params: { connection_public_id: @connection.public_id }
    authorize_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-no-identity" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => @connection.entra_client_id,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-no-identity" },
    )

    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :unprocessable_content
  end

  test "callback rejects a replayed state" do
    post "/social/entra", params: { connection_public_id: @connection.public_id }
    state = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state")

    get "/social/entra/callback", params: { state: state, code: "authorization-code" }

    assert_response :found
    follow_redirect!

    assert_response :unprocessable_content

    get "/social/entra/callback", params: { state: state, code: "authorization-code" }

    assert_response :found
    follow_redirect!

    assert_response :unprocessable_content
  end

  test "app-surface OmniAuth providers are rejected on the org host" do
    post "/social/google", params: {}

    assert_response :not_found
  end

  # Phase 14: OmniAuth.config.allowed_request_methods = [:post] is set
  # globally in config/initializers/omniauth.rb and applies to every
  # mounted strategy, including Entra -- there is no per-provider override
  # to verify separately.
  test "GET /social/entra (request phase) is rejected; only POST starts the ceremony" do
    get "/social/entra", params: { connection_public_id: @connection.public_id }

    assert_response :not_found
  end

  # --- parity with the legacy Auth::Org::Sign::In::Entra::* suite ---

  test "session/new is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    get new_auth_org_social_entra_session_path(connection: @connection.public_id, ri: "jp")

    assert_response :not_found
  end

  test "session/new is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    get new_auth_org_social_entra_session_path(connection: @connection.public_id, ri: "jp")

    assert_response :not_found
  end

  test "POST /social/entra is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    post "/social/entra", params: { connection_public_id: @connection.public_id }

    assert_response :not_found
  end

  test "POST /social/entra is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    post "/social/entra", params: { connection_public_id: @connection.public_id }

    assert_response :not_found
  end

  test "GET /social/entra/callback is unreachable from the app surface host" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/social/entra/callback", params: { state: "irrelevant", code: "irrelevant" }

    assert_response :not_found
  end

  test "GET /social/entra/callback is unreachable from the com surface host" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    get "/social/entra/callback", params: { state: "irrelevant", code: "irrelevant" }

    assert_response :not_found
  end

  test "request phase fails closed when the Entra provider is unavailable" do
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }

    # Stubs the availability factory rather than mutating real ENV, so this
    # test cannot leak state into other tests under parallel execution.
    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled) do
      post("/social/entra", params: { connection_public_id: @connection.public_id })
    end

    assert_response :found
    assert_match %r{\A/social/entra/failure}, response.location
  end

  test "callback renders error when the operator's entra method is locked by an in-force method_protection case" do
    operator = operators(:one)
    admin_operator = operators(:two)
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      connection_id: @connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
    the_case = OrgEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: operator.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: operator.public_id,
      authentication_method: "entra",
      effect: "unusable",
      effective_at: Time.current,
    )
    the_case.apply!

    post "/social/entra", params: { connection_public_id: @connection.public_id }
    authorize_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    state = authorize_query.fetch("state")
    nonce = authorize_query.fetch("nonce")

    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-locked" })
    jwks_loader = ->(_opts) { { "keys" => [jwk.export] } }
    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => @connection.entra_client_id,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-locked" },
    )

    # With a matching state/nonce and an active identity + active operator,
    # this would otherwise succeed -- the 422 here proves the authentication
    # method lock check fires, not an earlier verification failure.
    stub_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                loader_double = Object.new
                loader_double.define_singleton_method(:loader) { jwks_loader }
                loader_double
              },
      ) do
        get "/social/entra/callback", params: { state: state, code: "authorization-code" }
      end
    end

    assert_response :unprocessable_content
  end

  private

  def stub_entra_access_token(id_token, &)
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    original = strategy_class.instance_method(:access_token)
    strategy_class.define_method(:access_token) do
      verify_id_token!(id_token)
      OpenStruct.new(id_token: id_token)
    end
    yield
  ensure
    strategy_class.define_method(:access_token, original)
  end
end
