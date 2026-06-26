# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/auth_helpers"

class AcmeOauthOidcAuthorityTest < ActionDispatch::IntegrationTest
  include AuthHelpers

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

  test "acme app well-known discovery advertises acme issuer and protocol endpoints" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    get acme_app_well_known_discovery_url(host: host)

    assert_response :ok
    body = response.parsed_body
    issuer = OidcIssuer.for_resource_type("client")

    assert_equal issuer, body["issuer"]
    assert_equal "#{issuer}/oauth/authorize", body["authorization_endpoint"]
    assert_equal "#{issuer}/oauth/token", body["token_endpoint"]
    assert_equal "#{issuer}/oauth/userinfo", body["userinfo_endpoint"]
    assert_equal "#{issuer}/oauth/revoke", body["revocation_endpoint"]
    assert_equal "#{issuer}/oidc/logout", body["end_session_endpoint"]
    assert_equal "#{issuer}/.well-known/jwks.json", body["jwks_uri"]
  end

  test "acme com and org well-known discovery advertise surface-specific acme issuers" do
    get acme_com_well_known_discovery_url(host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))

    assert_response :ok
    assert_equal OidcIssuer.for_resource_type("visitor"), response.parsed_body["issuer"]

    get acme_org_well_known_discovery_url(host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))

    assert_response :ok
    assert_equal OidcIssuer.for_resource_type("operator"), response.parsed_body["issuer"]
  end

  test "sign discovery route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/.well-known/openid-configuration",
        method: :get,
      )
    end
  end

  test "sign jwks remains public compatibility metadata only" do
    get sign_app_well_known_jwks_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :ok
    response.parsed_body.fetch("keys").each do |key|
      assert_equal "ES384", key.fetch("alg")
      assert_not key.key?("d"), "private key material must not be exposed"
    end
  end

  test "oidc issuer uses acme hosts and signing namespaces" do
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), OidcIssuer.host_for_resource_type("client")
    assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), OidcIssuer.host_for_resource_type("visitor")
    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), OidcIssuer.host_for_resource_type("operator")
    assert_equal "surface:ACME_APP", OidcIssuer.jwt_issuer_id_for_resource_type("client")
    assert_equal "surface:ACME_COM", OidcIssuer.jwt_issuer_id_for_resource_type("visitor")
    assert_equal "surface:ACME_ORG", OidcIssuer.jwt_issuer_id_for_resource_type("operator")
  end

  test "acme token endpoint delegates exchange with acme endpoint binding" do
    captured = nil
    result = TokenResult.new(
      success: true,
      token_response: { access_token: "access", refresh_token: "refresh", token_type: "Bearer" },
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post acme_app_oauth_token_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "code",
             redirect_uri: "https://client.example/callback",
             client_id: "core-next-rp",
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

  test "acme token endpoint rejects missing csrf metadata with oauth json error instead of csrf 422" do
    result = TokenResult.new(
      success: false,
      error: "invalid_grant",
      error_description: "invalid_code",
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { result }) do
      post acme_app_oauth_token_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "bad-code",
             redirect_uri: "https://client.example/callback",
             client_id: "core-next-rp",
             client_secret: "secret",
             code_verifier: "verifier",
           }
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_equal "invalid_code", response.parsed_body["error_description"]
  end

  test "sign token endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end

  test "acme well-known discovery uses the external openid configuration path" do
    assert_recognizes_acme_route(
      ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "acme/app/well_known/discoveries",
      "show",
    )
    assert_recognizes_acme_route(
      ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "acme/com/well_known/discoveries",
      "show",
    )
    assert_recognizes_acme_route(
      ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "acme/org/well_known/discoveries",
      "show",
    )
  end

  test "acme token endpoint rejects get" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/oauth/token",
        method: :get,
      )
    end
  end

  test "acme authorize endpoint uses request windows and ignores old token history" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear

    create_old_client_tokens(count: 25)

    get acme_app_oauth_authorization_url(
      host: host,
      **oidc_authorize_params(scope: "openid"),
    ), headers: { "Host" => host }

    assert_response :redirect
    assert_not_equal 429, response.status
  end

  test "acme authorize endpoint rate limits repeated requests and sets retry after" do
    profile_set = RateLimitProfiles::AuthorizeProfileSet.new(
      ip_surface: RateLimitProfiles::Profile.new(to: 1, within: 1.minute, retry_after: 60),
      browser_client: RateLimitProfiles::Profile.new(to: 100, within: 1.minute, retry_after: 60),
      client_redirect_host: RateLimitProfiles::Profile.new(to: 100, within: 10.minutes, retry_after: 600),
    )

    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear

    logs = []
    Rails.logger.stub(:info, ->(*args, &_block) { logs << args.first if args.first.present? }) do
      RateLimitProfiles.stub(:oauth_authorize, profile_set) do
        get acme_app_oauth_authorization_url(
          host: host,
          **oidc_authorize_params(scope: "openid"),
        ), headers: { "Host" => host }

        assert_response :redirect

        get acme_app_oauth_authorization_url(
          host: host,
          **oidc_authorize_params(scope: "openid"),
        ), headers: { "Host" => host }

        assert_response :too_many_requests
        assert_equal "rails", response.headers["X-RateLimit-Layer"]
        assert_equal "oauth_authorize_ip_surface", response.headers["X-RateLimit-Rule"]
        assert_equal "60", response.headers["Retry-After"]
      end
    end

    assert logs.any? { |message| message.include?("oidc.authorize.rate_limited") }
  end

  test "acme userinfo authenticates against acme request binding" do
    captured = nil
    result = AuthResult.new(success: false, error: "invalid_token")

    OidcAccessTokenAuthenticator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      get acme_app_oauth_userinfo_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
          headers: { "Authorization" => "Bearer access", "DPoP" => "proof" }
    end

    assert_response :unauthorized
    assert_equal "client", captured[:resource_type]
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), captured[:host]
    assert_equal "Bearer", captured[:authorization_scheme]
    assert_equal "proof", captured[:dpop_proof]
  end

  test "acme userinfo returns bearer challenge headers on invalid token and insufficient scope" do
    invalid_result = AuthResult.new(success: false, error: "invalid_token")
    insufficient_result = AuthResult.new(success: false, error: "insufficient_scope")

    OidcAccessTokenAuthenticator.stub(:call, ->(**) { invalid_result }) do
      get acme_app_oauth_userinfo_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))

      assert_response :unauthorized
      assert_equal 'Bearer error="invalid_token"', response.headers["WWW-Authenticate"]
    end

    OidcAccessTokenAuthenticator.stub(:call, ->(**) { insufficient_result }) do
      get acme_app_oauth_userinfo_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))

      assert_response :forbidden
      assert_equal 'Bearer error="insufficient_scope", scope="openid"', response.headers["WWW-Authenticate"]
    end
  end

  test "sign userinfo endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/userinfo",
        method: :get,
      )
    end
  end

  test "acme revocation delegates with acme host binding" do
    captured = nil
    result = RevocationResult.new(success: true)

    OidcTokenRevoker.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post acme_app_oauth_revocation_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           params: {
             token: "refresh",
             client_id: "core-next-rp",
             client_secret: "secret",
             token_type_hint: "refresh_token",
           }
    end

    assert_response :ok
    assert_equal "refresh", captured[:token]
    assert_equal "core-next-rp", captured[:client_id]
    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), captured[:host]
  end

  test "sign revocation endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/revoke",
        method: :post,
      )
    end
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

  test "acme app token check authenticates a valid client session" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token_record = ClientToken.create!(user: user)
    token_record.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token_record.device_session.public_id,
      oidc_jti: token_record.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: "surface:ACME_APP",
    )

    host!(host)

    get "/edge/v0/token/check",
        headers: { "Host" => host, "Accept" => "application/json", "Authorization" => "Bearer #{access_token}" },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal "client", response.parsed_body["type"]
    assert_equal user.id, response.parsed_body["id"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "acme org token check authenticates a valid operator session" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    token_record = OperatorToken.create!(staff: staff)
    token_record.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      staff,
      host: host,
      session_public_id: token_record.device_session.public_id,
      oidc_jti: token_record.oidc_jti,
      resource_type: "operator",
      jwt_issuer_id: "surface:ACME_ORG",
    )

    host!(host)

    get "/edge/v0/token/check",
        headers: { "Host" => host, "Accept" => "application/json", "Authorization" => "Bearer #{access_token}" },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal "operator", response.parsed_body["type"]
    assert_equal staff.id, response.parsed_body["id"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "acme app token check without credentials returns unauthorized" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    host!(host)
    get "/edge/v0/token/check", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

    assert_response :unauthorized
    assert_equal({ "authenticated" => false }, response.parsed_body)
  end

  test "acme edge token refresh rejects missing refresh token without rotation" do
    AcmeRefreshTokenIssuer.stub(:call, ->(**) { flunk("refresh rotation must not run without a token") }) do
      post acme_app_edge_v0_token_refresh_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
           as: :json
    end

    assert_response :bad_request
    assert_equal "missing_refresh_token", response.parsed_body["error_code"]
  end

  test "refresh authority source uses acme service not sign refresh service" do
    source = Rails.root.join("app/controllers/concerns/authentication_base.rb").read

    assert_includes source, "AcmeRefreshTokenIssuer.call"
    assert_not_includes source, "SignRefreshTokenIssuer.call"

    %w(app com org).each do |surface|
      assert_not Rails.root.join("app/controllers/sign/#{surface}/edge/v0/token/refreshes_controller.rb").exist?
    end
  end

  test "acme oidc logout consumes signed request and completes on acme sign out" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    logout_request = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    get(
      acme_app_oidc_logout_url(host: host),
      params: {
        client_id: "base-rails-rp",
        logout_request: logout_request,
        ri: "jp",
      },
      headers: {
        "Host" => host,
        "X-TEST-CURRENT-USER" => user.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      },
    )

    assert_response :ok
    assert_not_predicate token.reload, :revoked?

    post(
      acme_app_oidc_logout_url(host: host),
      params: {
        client_id: "base-rails-rp",
        logout_request: logout_request,
        ri: "jp",
      },
      headers: {
        "Host" => host,
        "X-TEST-CURRENT-USER" => user.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      },
    )

    assert_response :success
    assert_not_predicate token.reload, :revoked?
    assert_includes response.body, I18n.t("sign.shared.sign_out.title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.confirm_description")
  end

  test "acme oauth authorize starts sign in ceremony on unauthenticated requests" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)

    get "/oauth/authorize", params: oidc_authorize_params, headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ID_SERVICE_URL", "id.app.localhost"), uri.host
    assert_equal "/sign/in", uri.path
    assert_predicate query["login_challenge"], :present?

    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: query["login_challenge"])

    assert_equal "app", transaction.surface
    assert_equal "sign_in", transaction.intent
    assert_equal "openid profile", transaction.scope
  end

  test "acme oauth authorize issues a code immediately for an already authenticated browser session" do
    [
      {
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        actor: clients(:one),
        token: ->(actor) do
          ClientToken.create!(
            user: actor,
            user_token_kind_id: ClientTokenKind::BROWSER_WEB,
            user_token_status_id: ClientTokenStatus::ACTIVE,
          )
        end,
        transaction_class: ClientOidcAuthorizationTransaction,
        header_builder: ->(actor, host:, session_public_id:) do
          as_user_headers(actor, host: host, session_public_id: session_public_id)
        end,
      },
      {
        host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
        actor: operators(:one),
        token: ->(actor) do
          OperatorToken.create!(
            staff: actor,
            staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
            staff_token_status_id: OperatorTokenStatus::ACTIVE,
          )
        end,
        transaction_class: OperatorOidcAuthorizationTransaction,
        header_builder: ->(actor, host:, session_public_id:) do
          as_staff_headers(actor, host: host, session_public_id: session_public_id)
        end,
      },
      {
        host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
        actor: create_visitor!,
        token: ->(actor) do
          VisitorToken.create!(
            visitor: actor,
            visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
            visitor_token_status_id: VisitorTokenStatus::ACTIVE,
          )
        end,
        transaction_class: VisitorOidcAuthorizationTransaction,
        header_builder: ->(actor, host:, session_public_id:) do
          host_headers(host).merge(
            TEST_RESOURCE_HEADER => actor.id.to_s,
            "X-TEST-SESSION-PUBLIC-ID" => session_public_id,
          )
        end,
      },
    ].each do |surface|
      host = surface.fetch(:host)
      actor = surface.fetch(:actor)
      token = surface.fetch(:token).call(actor)
      headers = surface.fetch(:header_builder).call(actor, host: host, session_public_id: token.public_id)

      host!(host)

      assert_no_difference -> { surface.fetch(:transaction_class).count } do
        get "/oauth/authorize", params: oidc_authorize_params, headers: headers
      end

      assert_response :redirect
      uri = URI.parse(response.location)
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "jump.umaxica.net", uri.host
      assert_equal URI.parse(oidc_authorize_params[:redirect_uri]).host, callback_uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate query["code"], :present?
      assert_equal oidc_authorize_params[:state], query["state"]
      assert_not_includes callback_uri.query.to_s, "login_challenge"
    end
  end

  test "acme oauth authorize starts sign up ceremony when screen_hint requests signup" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)

    get "/oauth/authorize", params: oidc_authorize_params(screen_hint: "signup"), headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal ENV.fetch("ID_SERVICE_URL", "id.app.localhost"), uri.host
    assert_equal "/sign/up", uri.path
  end

  test "acme oauth authorize rejects requests without openid scope" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)

    assert_no_difference "ClientOidcAuthorizationTransaction.count" do
      get "/oauth/authorize", params: oidc_authorize_params(scope: "profile email"), headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_equal "scope must include openid", response.parsed_body["error_description"]
  end

  test "acme oauth authorize rejects scopes outside the client allowlist" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)

    assert_no_difference "ClientOidcAuthorizationTransaction.count" do
      get "/oauth/authorize", params: oidc_authorize_params(scope: "openid palm.read"), headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
  end

  test "acme oauth authorize consumes login challenge once" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: oidc_authorize_params,
    )

    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: issuance.transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-1",
      auth_method: "passkey",
    )

    get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge }, headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_predicate query["code"], :present?
    assert_equal oidc_authorize_params[:state], query["state"]
    assert_predicate issuance.transaction.reload, :consumed?

    get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge }, headers: browser_headers

    assert_response :bad_request
    assert_equal "authorization transaction already consumed", response.parsed_body["error_description"]
  end

  test "acme oauth authorize rejects expired login challenge" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host!(host)
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: oidc_authorize_params,
        login_challenge_ttl: 1.second,
        now: Time.current,
      )

    travel 2.seconds do
      get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge },
                              headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body["error_description"]
  end

  private

  def oidc_authorize_params(screen_hint: nil, scope: "openid profile")
    params = {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: scope,
    }
    params[:screen_hint] = screen_hint if screen_hint.present?
    params
  end

  def create_old_client_tokens(count:)
    user = clients(:one)

    OrgTicketRecord.connected_to(role: :writing) do
      count.times do |index|
        token = ClientToken.new(
          user: user,
          user_token_status_id: ClientTokenStatus::ACTIVE,
          created_at: (count + index + 1).hours.ago,
          updated_at: (count + index + 1).hours.ago,
        )
        token.send(:skip_session_limit_check=, true)
        token.save!
      end
    end
  end

  def assert_recognizes_acme_route(host, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

    assert_equal controller_name, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
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
end
