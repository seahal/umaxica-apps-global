# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeOauthOidcAuthorityTest < ActionDispatch::IntegrationTest
  TokenResult =
    Struct.new(:success, :token_response, :error, :error_description, keyword_init: true) do
      def success? = success
    end

  AuthResult =
    Struct.new(:success, :payload, :token, :resource, :error, keyword_init: true) do
      def success? = success
    end

  RevocationResult =
    Struct.new(:success, :error, :error_description, keyword_init: true) do
      def success? = success
    end

  test "acme app discovery advertises acme issuer and protocol endpoints" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    get acme_app_openid_configuration_url(host: host)

    assert_response :ok
    body = response.parsed_body
    issuer = Oidc::Issuer.for_resource_type("client")

    assert_equal issuer, body["issuer"]
    assert_equal "#{issuer}/oauth/authorize", body["authorization_endpoint"]
    assert_equal "#{issuer}/oauth/token", body["token_endpoint"]
    assert_equal "#{issuer}/oauth/userinfo", body["userinfo_endpoint"]
    assert_equal "#{issuer}/oauth/revoke", body["revocation_endpoint"]
    assert_equal "#{issuer}/oidc/logout", body["end_session_endpoint"]
    assert_equal "#{issuer}/.well-known/jwks.json", body["jwks_uri"]
  end

  test "acme com and org discovery advertise surface-specific acme issuers" do
    get acme_com_openid_configuration_url(host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))

    assert_response :ok
    assert_equal Oidc::Issuer.for_resource_type("visitor"), response.parsed_body["issuer"]

    get acme_org_openid_configuration_url(host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))

    assert_response :ok
    assert_equal Oidc::Issuer.for_resource_type("operator"), response.parsed_body["issuer"]
  end

  test "sign discovery is compatibility metadata for acme issuer" do
    get sign_app_openid_configuration_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :ok
    assert_equal Oidc::Issuer.for_resource_type("client"), response.parsed_body["issuer"]
    assert_not_includes response.parsed_body["issuer"], ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    assert_includes response.parsed_body["token_endpoint"], ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    assert_includes response.parsed_body["jwks_uri"], ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  end

  test "sign jwks remains public compatibility metadata only" do
    get sign_app_jwks_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :ok
    response.parsed_body.fetch("keys").each do |key|
      assert_equal "ES384", key.fetch("alg")
      assert_not key.key?("d"), "private key material must not be exposed"
    end
  end

  test "oidc issuer uses acme hosts and signing namespaces" do
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), Oidc::Issuer.host_for_resource_type("client")
    assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), Oidc::Issuer.host_for_resource_type("visitor")
    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), Oidc::Issuer.host_for_resource_type("operator")
    assert_equal "surface:ACME_APP", Oidc::Issuer.jwt_issuer_id_for_resource_type("client")
    assert_equal "surface:ACME_COM", Oidc::Issuer.jwt_issuer_id_for_resource_type("visitor")
    assert_equal "surface:ACME_ORG", Oidc::Issuer.jwt_issuer_id_for_resource_type("operator")
  end

  test "acme token endpoint delegates exchange with acme endpoint binding" do
    captured = nil
    result = TokenResult.new(
      success: true,
      token_response: { access_token: "access", refresh_token: "refresh", token_type: "Bearer" },
    )

    Oidc::TokenExchangeService.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post acme_app_oauth_token_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "code",
             redirect_uri: "https://client.example/callback",
             client_id: "core_app",
             client_secret: "secret",
             code_verifier: "verifier",
           },
           headers: { "DPoP" => "proof" }
    end

    assert_response :ok
    assert_equal "proof", captured[:dpop_proof]
    assert_equal "POST", captured[:request_method]
    assert_includes captured[:token_endpoint_uri], "/oauth/token"
    assert_includes captured[:token_endpoint_uri], ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
  end

  test "sign token endpoint is compatibility wrapper and does not select sign issuer namespace" do
    captured = nil
    result = TokenResult.new(
      success: true,
      token_response: { access_token: "access", refresh_token: "refresh", token_type: "Bearer" },
    )

    Oidc::TokenExchangeService.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post sign_app_oauth_token_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "code",
             redirect_uri: "https://client.example/callback",
             client_id: "core_app",
             client_secret: "secret",
             code_verifier: "verifier",
           }
    end

    assert_response :ok
    assert_equal "POST", captured[:request_method]
    assert_includes captured[:token_endpoint_uri], ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    assert_equal "surface:ACME_APP", Oidc::Issuer.jwt_issuer_id_for_resource_type("client")
  end

  test "acme token endpoint rejects get" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/oauth/token",
        method: :get,
      )
    end
  end

  test "acme userinfo authenticates against acme request binding" do
    captured = nil
    result = AuthResult.new(success: false, error: "invalid_token")

    Oidc::AccessTokenAuthenticator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      get acme_app_oauth_user_info_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
          headers: { "Authorization" => "Bearer access", "DPoP" => "proof" }
    end

    assert_response :unauthorized
    assert_equal "client", captured[:resource_type]
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), captured[:host]
    assert_equal "Bearer", captured[:authorization_scheme]
    assert_equal "proof", captured[:dpop_proof]
  end

  test "sign userinfo is compatibility wrapper over acme issuer authenticator" do
    captured = nil
    result = AuthResult.new(success: false, error: "invalid_token")

    Oidc::AccessTokenAuthenticator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      get sign_app_oauth_user_info_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
          headers: { "Authorization" => "Bearer access" }
    end

    assert_response :unauthorized
    assert_equal "client", captured[:resource_type]
    assert_equal ENV.fetch("ID_SERVICE_URL", "id.app.localhost"), captured[:host]
    assert_equal "surface:ACME_APP", Oidc::Issuer.jwt_issuer_id_for_resource_type("client")
  end

  test "acme revocation delegates with acme host binding" do
    captured = nil
    result = RevocationResult.new(success: true)

    Oidc::TokenRevocationService.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post acme_app_oauth_revocation_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           params: {
             token: "refresh",
             client_id: "core_app",
             client_secret: "secret",
             token_type_hint: "refresh_token",
           }
    end

    assert_response :ok
    assert_equal "refresh", captured[:token]
    assert_equal "core_app", captured[:client_id]
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), captured[:host]
  end

  test "sign revocation is compatibility wrapper over shared revocation service" do
    captured = nil
    result = RevocationResult.new(success: true)

    Oidc::TokenRevocationService.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post sign_app_oauth_revocation_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
           params: {
             token: "refresh",
             client_id: "core_app",
             client_secret: "secret",
             token_type_hint: "refresh_token",
           }
    end

    assert_response :ok
    assert_equal "refresh", captured[:token]
    assert_equal "core_app", captured[:client_id]
    assert_equal "surface:ACME_APP", Oidc::Issuer.jwt_issuer_id_for_resource_type("client")
  end

  test "acme edge token refresh is post only and does not accept url-only mutation" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/edge/v0/token/refresh",
        method: :get,
      )
    end

    assert_equal(
      "acme/app/edge/v0/token/refreshes#create",
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/edge/v0/token/refresh",
        method: :post,
      ).values_at(:controller, :action).join("#"),
    )
  end

  test "acme edge token refresh rejects missing refresh token without rotation" do
    Acme::RefreshTokenService.stub(:call, ->(**) { flunk("refresh rotation must not run without a token") }) do
      post acme_app_edge_v0_token_refresh_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           as: :json
    end

    assert_response :bad_request
    assert_equal "missing_refresh_token", response.parsed_body["error_code"]
  end

  test "refresh authority source uses acme service not sign refresh service" do
    source = Rails.root.join("app/controllers/concerns/authentication/base.rb").read

    assert_includes source, "Acme::RefreshTokenService.call"
    assert_not_includes source, "Sign::RefreshTokenService.call"

    %w(app com org).each do |surface|
      refresh_source = Rails.root.join("app/controllers/sign/#{surface}/edge/v0/token/refreshes_controller.rb").read

      assert_not_includes refresh_source, "Sign::RefreshTokenService"
    end
  end

  test "acme oidc logout consumes signed request and completes on acme sign out" do
    Oidc::LogoutRequest.replay_store = ActiveSupport::Cache::MemoryStore.new
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    get(
      acme_app_oidc_logout_url(host: host),
      params: {
        client_id: "acme_app",
        logout_request: Oidc::LogoutRequest.issue(client_id: "acme_app", ri: "jp"),
        ri: "jp",
      },
    )

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal host, location.host
    assert_equal "/sign/out", location.path
    assert_equal "ri=jp", location.query
  ensure
    Oidc::LogoutRequest.replay_store = nil
  end
end
