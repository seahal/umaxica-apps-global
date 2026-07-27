# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require "jwt"

class Auth::Org::Sign::In::EntrasControllerTest < ActionDispatch::IntegrationTest
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  RI        = "jp"

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear
    @entra_social_ceremony_enabled = ENV["ENTRA_SOCIAL_CEREMONY_ENABLED"]
    ENV["ENTRA_SOCIAL_CEREMONY_ENABLED"] = "true"
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    if @entra_social_ceremony_enabled.nil?
      ENV.delete("ENTRA_SOCIAL_CEREMONY_ENABLED")
    else
      ENV["ENTRA_SOCIAL_CEREMONY_ENABLED"] = @entra_social_ceremony_enabled
    end
  end

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @active_connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "entra-controller-test-client",
      entra_client_secret: "controller-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  # --- routing ---

  test "GET /sign/in/entra/new is routable" do
    get new_auth_org_sign_in_entra_path(ri: RI)

    assert_response :success
  end

  test "POST /sign/in/entra/authorization is routable" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    assert_not_equal 404, response.status
  end

  test "GET /sign/in/entra/callback is routable" do
    get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: "x", code: "y" }

    assert_response :unprocessable_content
  end

  # --- new action ---

  test "new renders page with Entra button when connection is active" do
    get new_auth_org_sign_in_entra_path(ri: RI), params: { connection: @active_connection.public_id }

    assert_response :success
    assert_select "form[action=?]", auth_org_sign_in_entra_authorization_path(ri: RI)
    assert_select "input[type=hidden][name='entra[connection_public_id]'][value=?]",
                  @active_connection.public_id
  end

  test "new renders without Entra button when connection public_id is missing" do
    get new_auth_org_sign_in_entra_path(ri: RI)

    assert_response :success
    assert_select "form[action=?]", auth_org_sign_in_entra_authorization_path(ri: RI), count: 0
  end

  test "new renders without Entra button when connection is not active" do
    inactive_connection = OrganizationEntraConnection.create!(
      organization_id: 2,
      entra_tenant_id: "22222222-3333-4444-5555-666666666666",
      entra_client_id: "inactive-client",
      entra_client_secret: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    get new_auth_org_sign_in_entra_path(ri: RI), params: { connection: inactive_connection.public_id }

    assert_response :success
    assert_select "form[action=?]", auth_org_sign_in_entra_authorization_path(ri: RI), count: 0
  end

  test "new renders without Entra button for unknown connection public_id" do
    get new_auth_org_sign_in_entra_path(ri: RI), params: { connection: "ZZZ999ZZZ999ZZZ999ZZZ" }

    assert_response :success
    assert_select "form[action=?]", auth_org_sign_in_entra_authorization_path(ri: RI), count: 0
  end

  # --- authorization action ---

  test "authorization redirects to Entra authorization endpoint" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    assert_response :redirect
    redirect_uri = URI.parse(response.location)

    assert_equal "login.microsoftonline.com", redirect_uri.host
    assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", redirect_uri.path
  end

  test "authorization redirect includes required OAuth2 params" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

    assert_equal @active_connection.entra_client_id, query["client_id"]
    assert_equal "code", query["response_type"]
    assert_equal "openid profile", query["scope"]
    assert_equal "S256", query["code_challenge_method"]
    assert_predicate query["state"], :present?
    assert_predicate query["nonce"], :present?
    assert_predicate query["code_challenge"], :present?
    assert_predicate query["redirect_uri"], :present?
  end

  test "authorization stores only an opaque ceremony reference in session" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    assert_predicate session[:external_authentication_ceremony_reference], :present?
    assert_nil session[:entra_state]
    assert_nil session[:entra_nonce]
    assert_nil session[:entra_code_verifier]
  end

  test "authorization renders error when connection_public_id is missing" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: "" } }

    assert_response :unprocessable_content
  end

  test "authorization stops before issuing a ceremony when Entra is disabled" do
    ENV["ENTRA_SOCIAL_CEREMONY_ENABLED"] = "false"

    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    assert_response :unprocessable_content
    assert_nil session[:external_authentication_ceremony_reference]
  end

  test "authorization renders error when connection is not active" do
    inactive_connection = OrganizationEntraConnection.create!(
      organization_id: 3,
      entra_tenant_id: "33333333-4444-5555-6666-777777777777",
      entra_client_id: "inactive-client-2",
      entra_client_secret: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: inactive_connection.public_id } }

    assert_response :unprocessable_content
  end

  test "authorization state in session matches state in the Entra redirect URL" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }

    session_state = entra_ceremony_payload.fetch("state")
    redirect_state = Rack::Utils.parse_nested_query(URI.parse(response.location).query)["state"]

    assert_equal session_state, redirect_state
  end

  # --- callback action: state verification ---

  test "callback renders error when state param is missing" do
    get auth_org_sign_in_entra_callback_path(ri: RI), params: { code: "auth-code" }

    assert_response :unprocessable_content
  end

  test "callback renders error when state does not match session" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    reference = session.fetch(:external_authentication_ceremony_reference)

    get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: "wrong-state", code: "auth-code" }

    assert_response :unprocessable_content
    assert_nil session[:external_authentication_ceremony_reference]
    assert_nil Rails.cache.read("external-authentication/org-entra-ceremony/#{reference}")
  end

  test "callback renders error when Entra returns an error param" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    state = entra_ceremony_payload.fetch("state")

    get auth_org_sign_in_entra_callback_path(ri: RI),
        params: { state: state, error: "access_denied", error_description: "User denied consent" }

    assert_response :unprocessable_content
    assert_nil session[:external_authentication_ceremony_reference]
  end

  test "callback clears state from session to prevent replay" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    state = entra_ceremony_payload.fetch("state")

    get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "code" }

    # State was consumed by the first callback; second attempt with the same state must fail
    get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "code" }

    assert_response :unprocessable_content
  end

  # --- callback action: token exchange failure ---

  test "callback renders error when token exchange fails" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    state = entra_ceremony_payload.fetch("state")

    failed_result = OidcRpTokenClient::Result.new(success: false, token_response: nil, error: "invalid_grant")
    OidcRpTokenClient.stub(:call, failed_result) do
      get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "bad-code" }
    end

    assert_response :unprocessable_content
    assert_nil session[:external_authentication_ceremony_reference]
  end

  # --- callback action: token verification failure ---

  test "callback renders error when id_token is not a valid JWT" do
    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    state = entra_ceremony_payload.fetch("state")

    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: { "id_token" => "not.a.valid-jwt-signature" },
      error: nil,
    )
    OidcRpTokenClient.stub(:call, token_result) do
      get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "code" }
    end

    assert_response :unprocessable_content
  end

  # --- callback action: identity not found ---

  test "callback renders error when no OperatorEntraIdentity exists for the token claims" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid" })
    jwks = { "keys" => [jwk.export] }
    jwks_loader = ->(_opts) { jwks }

    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    nonce = entra_ceremony_payload.fetch("nonce")
    state = entra_ceremony_payload.fetch("state")

    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => @active_connection.entra_client_id,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid" },
    )

    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: { "id_token" => id_token },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, token_result) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                stub_loader = Object.new
                stub_loader.define_singleton_method(:loader) { jwks_loader }
                stub_loader
              },
      ) do
        get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "code" }
      end
    end

    # No OperatorEntraIdentity provisioned -> IdentityNotFoundError -> 422
    assert_response :unprocessable_content
  end

  # --- callback action: operator access control ---

  test "callback renders error when operator login is not allowed" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-kid-login" })
    jwks = { "keys" => [jwk.export] }
    jwks_loader = ->(_opts) { jwks }

    post auth_org_sign_in_entra_authorization_path(ri: RI),
         params: { entra: { connection_public_id: @active_connection.public_id } }
    nonce = entra_ceremony_payload.fetch("nonce")
    state = entra_ceremony_payload.fetch("state")

    now = Time.now.to_i
    id_token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => @active_connection.entra_client_id,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-sub",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => "test-kid-login" },
    )

    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: { "id_token" => id_token },
      error: nil,
    )

    OperatorEntraIdentity.create!(
      operator_id: 99_999,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    # Operator.find_by returns nil -> login_allowed? check fails -> 422
    OidcRpTokenClient.stub(:call, token_result) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
                stub_loader = Object.new
                stub_loader.define_singleton_method(:loader) { jwks_loader }
                stub_loader
              },
      ) do
        get auth_org_sign_in_entra_callback_path(ri: RI), params: { state: state, code: "code" }
      end
    end

    assert_response :unprocessable_content
  end

  # --- surface isolation ---

  test "new is unreachable from the app surface host" do
    app_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{app_host}/sign/in/entra/new", method: :get,
      )
    end
  end

  test "new is unreachable from the com surface host" do
    com_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{com_host}/sign/in/entra/new", method: :get,
      )
    end
  end

  test "authorization is unreachable from the app surface host" do
    app_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{app_host}/sign/in/entra/authorization", method: :post,
      )
    end
  end

  test "authorization is unreachable from the com surface host" do
    com_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{com_host}/sign/in/entra/authorization", method: :post,
      )
    end
  end

  test "callback is unreachable from the app surface host" do
    app_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{app_host}/sign/in/entra/callback", method: :get,
      )
    end
  end

  test "callback is unreachable from the com surface host" do
    com_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{com_host}/sign/in/entra/callback", method: :get,
      )
    end
  end

  private

  def entra_ceremony_payload
    {
      "state" => Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state"),
      "nonce" => "test-nonce-not-used-for-controller-failure-path",
    }
  end
end
