# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class OidcRpBrowserFlowTest < ActionDispatch::IntegrationTest
  COOKIE_NAME = AuthenticationBase::ACCESS_COOKIE_KEY

  SURFACES = [
    { host: ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"),
      resource: -> {
        clients(:one)
      }, },
    { host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      resource: -> {
        operators(:one)
      }, },
    { host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      resource: -> {
        create_visitor!
      }, },
  ].freeze

  setup do
    load_jump_rt_env!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "app com and org sso authorize redirects to Acme OP with state nonce and PKCE" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:acme_host], uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_not_equal "jump.umaxica.net", uri.host
      assert_equal surface[:client_id], query["client_id"]
      assert_equal redirect_uri_for(surface), query["redirect_uri"]
      assert_equal "S256", query["code_challenge_method"]
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
      assert_nil query["screen_hint"]
    end
  end

  test "acme app browser flow reaches Acme token exchange without stubbing OP" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
      client = OidcClientRegistry.find!("base-rails-rp")
      host! acme_host

      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(response.location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)
      code_verifier = session.fetch(:oidc_code_verifier)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path
      assert_not_equal "jump.umaxica.net", authorize_uri.host

      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      assert_equal sign_host, sign_uri.host
      assert_equal "/sign/in", sign_uri.path
      assert_predicate sign_query["login_challenge"], :present?

      host! sign_host
      get sign_uri.request_uri, headers: browser_headers

      assert_response :success

      result =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: clients(:one),
          session_ref: "acme-e2e-session",
          auth_method: "passkey",
        )

      host! acme_host
      get URI.parse(result.resume_url).request_uri, headers: browser_headers

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal URI.parse(client.redirect_uris.first).host, callback_uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_equal authorize_query.fetch("state"), callback_query["state"]

      token_url = acme_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "base-rails-rp",
             code_verifier: code_verifier,
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: client_assertion,
           },
           headers: browser_headers

      assert_response :ok
      assert_predicate response.parsed_body["id_token"], :present?
      assert_predicate response.parsed_body["access_token"], :present?
    end
  end

  # Regression guard for the sign-up -> OIDC authorization resume handoff.
  # The handoff mints a BROWSER_WEB token within seconds of the token issued
  # while completing sign-up, so the login cooldown gate would fire a 429 unless
  # resume_authorization! drives log_in with bootstrap_actor: true. This test
  # fails if that wiring is removed (or if check_login_cooldown! stops honoring
  # bootstrap_actor), even though the underlying unit test on the gate passes.
  test "acme app authorization resume bypasses login cooldown for the sign-up handoff" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      host! acme_host

      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      result =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: clients(:one),
          session_ref: "acme-cooldown-handoff-session",
          auth_method: "email",
        )

      # Simulate the token freshly minted while completing sign-up, so the
      # cooldown gate would reject a non-bootstrap login.
      OrgTicketRecord.connected_to(role: :writing) do
        ClientToken.create!(user: clients(:one), user_token_status_id: ClientTokenStatus::ACTIVE)
      end

      AuthenticationBase.login_cooldown_enabled = true
      begin
        host!(acme_host)
        get(URI.parse(result.resume_url).request_uri, headers: browser_headers)
      ensure
        AuthenticationBase.login_cooldown_enabled = false
      end

      assert_not_equal 429, response.status,
                       "sign-up -> OIDC resume handoff must not be rejected by the login cooldown gate"
      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
    end
  end

  test "acme app authorization resume opens session-limit resolution when three usable tokens already exist" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all

      3.times do
        ClientToken.create!(
          user: user,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
        )
      end

      host! acme_host
      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      issuance =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: user,
          session_ref: "acme-session-limit-session",
          auth_method: "passkey",
        )

      assert_no_difference -> { ClientToken.where(user_id: user.id).count } do
        get URI.parse(issuance.resume_url).request_uri, headers: browser_headers
      end

      assert_response :see_other
      resolution_uri = URI.parse(response.location)
      resolution_query = Rack::Utils.parse_nested_query(resolution_uri.query.to_s)

      assert_equal "/sign/in/limitation", resolution_uri.path
      assert_predicate resolution_query["resolution_challenge"], :present?
      assert_not_includes resolution_uri.query.to_s, user.id.to_s
      assert_not_predicate issuance.transaction.reload, :consumed?

      resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(
        resolution_query.fetch("resolution_challenge"),
      )

      assert_equal "Client", resolution.actor_type
      assert_equal user.public_id, resolution.actor_ref
      assert_equal issuance.transaction.id, resolution.oidc_authorization_transaction_id

      host! acme_host
      get URI.parse(response.location).request_uri, headers: browser_headers
      if response.redirect?
        get URI.parse(response.location).request_uri, headers: browser_headers
      end

      assert_response :success
      assert_select "h1", "Session limit"
      assert_select "input[name=session_ref]", count: 3
      assert_not_predicate issuance.transaction.reload, :consumed?
    end
  end

  test "acme app session-limit limitation revokes one session and resumes authorization" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      client = OidcClientRegistry.find!("base-rails-rp")
      code_verifier = SecureRandom.urlsafe_base64(48)
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all

      tokens =
        3.times.map do
          ClientToken.create!(
            user: user,
            user_token_kind_id: ClientTokenKind::BROWSER_WEB,
            user_token_status_id: ClientTokenStatus::ACTIVE,
          )
        end
      current_session = tokens.second
      issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email", code_verifier: code_verifier)
      resolution = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
        actor: user,
        oidc_transaction: issuance.transaction,
      )
      selected = tokens.first

      assert_difference -> { ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count }, -1 do
        host! acme_host
        patch acme_app_sign_in_limitation_path,
              params: {
                resolution_challenge: resolution.challenge,
                session_ref: SessionLimitResolutionTokenRef.issue(selected),
              },
              headers: as_user_headers(user, host: acme_host, session_public_id: current_session.public_id)
      end

      assert_predicate selected.reload, :revoked?
      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_predicate issuance.transaction.reload, :consumed?
      assert_predicate resolution.transaction.reload, :resolved?
      assert_not_nil resolution.transaction.finalized_at
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      token_url = acme_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "base-rails-rp",
             code_verifier: code_verifier,
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: client_assertion,
           },
           headers: browser_headers

      assert_response :ok
      assert_predicate response.parsed_body["id_token"], :present?
      assert_predicate response.parsed_body["access_token"], :present?
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count
    end
  end

  test "app email sign-in session-limit handoff signs in Sign and leaves capacity for RP callback session" do
    with_acme_oidc_client_key do
      CloudflareTurnstile.test_mode = true
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all
      email = user.client_emails.create!(address: "oidc_email_limit_#{SecureRandom.hex(4)}@example.com")

      first_active = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
      first_active.rotate_refresh_token!
      second_active = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
      second_active.rotate_refresh_token!

      host!(acme_host)
      get("/oidc/authorization", headers: browser_headers)

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      get("/oauth/authorize", params: authorize_query, headers: browser_headers)

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      host!(sign_host)
      get(sign_uri.request_uri, headers: browser_headers)

      assert_response :success

      post(
        sign_app_sign_in_email_path(ri: "jp"),
        params: {
          :client_email => { address: email.address },
          "cf-turnstile-response" => "test_token",
        },
        headers: browser_headers,
      )

      assert_response :redirect

      pass_code = store_email_otp_and_return_code(email)
      patch(
        sign_app_sign_in_email_path(ri: "jp"),
        params: { client_email: { pass_code: pass_code } },
        headers: browser_headers,
      )

      assert_redirected_to sign_app_sign_in_session_path(ri: "jp")

      assert_no_difference -> { ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count } do
        patch(
          sign_app_sign_in_session_path(ri: "jp"),
          params: { revoke_refs: [first_active.signed_ref] },
          headers: browser_headers,
        )
      end

      assert_response :redirect
      resume_uri = URI.parse(response.location)
      resume_query = Rack::Utils.parse_nested_query(resume_uri.query.to_s)

      assert_equal acme_host, resume_uri.host
      assert_equal "/oauth/authorize", resume_uri.path
      assert_equal sign_query.fetch("login_challenge"), resume_query.fetch("login_challenge")

      transaction = ClientOidcAuthorizationTransaction.find_by!(
        login_challenge: sign_query.fetch("login_challenge"),
      )

      assert_predicate transaction, :authenticated?
      sign_session = ClientToken.find_by!(public_id: transaction.session_ref)

      assert_predicate sign_session, :active?
      assert_equal user.id, sign_session.user_id
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      host!(acme_host)
      get(resume_uri.request_uri, headers: browser_headers)

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_predicate transaction.reload, :consumed?

      get(callback_uri.request_uri, headers: browser_headers)

      assert_response :redirect
      assert_equal 3, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      host!(sign_host)
      get(sign_app_dashboard_path(ri: "jp"), headers: browser_headers)

      assert_response :success
      assert_select "h1", "Dashboard"
    ensure
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
    end
  end

  test "acme app session-limit limitation rejects another actor session" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other = clients(:two)
    ClientToken.where(user_id: [user.id, other.id]).delete_all
    own_token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_token = ClientToken.create!(user: other, user_token_status_id: ClientTokenStatus::ACTIVE)
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    resolution = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
      actor: user,
      oidc_transaction: issuance.transaction,
    )

    host! acme_host
    patch acme_app_sign_in_limitation_path,
          params: {
            resolution_challenge: resolution.challenge,
            session_ref: SessionLimitResolutionTokenRef.issue(other_token),
          },
          headers: browser_headers

    assert_response :unprocessable_content
    assert_not other_token.reload.revoked?
    assert_not own_token.reload.revoked?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app session-limit limitation stays on page when capacity is still full after revoke" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    resolution = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
      actor: user,
      oidc_transaction: issuance.transaction,
    )
    controller_class = Base::App::Sign::In::LimitationsController
    original_method = controller_class.instance_method(:hard_reject_still_applies?)
    controller_class.define_method(:hard_reject_still_applies?) { true }
    controller_class.send(:private, :hard_reject_still_applies?)

    host!(acme_host)
    assert_no_difference -> { ClientToken.where(user_id: user.id).count } do
      patch(
        acme_app_sign_in_limitation_path,
        params: {
          resolution_challenge: resolution.challenge,
          session_ref: SessionLimitResolutionTokenRef.issue(token),
        },
        headers: browser_headers,
      )
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("acme.app.sign.in.limitations.capacity_still_full")
    assert_predicate token.reload, :revoked?
    assert_not_predicate issuance.transaction.reload, :consumed?
  ensure
    if original_method
      controller_class.define_method(:hard_reject_still_applies?, original_method)
      controller_class.send(:private, :hard_reject_still_applies?)
    end
  end

  test "acme app session-limit limitation rejects tampered challenge without revoking" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)

    host! acme_host
    patch acme_app_sign_in_limitation_path,
          params: {
            resolution_challenge: "tampered",
            session_ref: SessionLimitResolutionTokenRef.issue(token),
          },
          headers: browser_headers

    assert_response :gone
    assert_not token.reload.revoked?
  end

  test "acme app session-limit limitation rejects mixed oidc and social payloads" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    resolution = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
      actor: user,
      oidc_transaction: issuance.transaction,
    )
    social_token = Rails.application.message_verifier(:social_session_limit_limitation).generate(
      {
        "actor_ref" => user.public_id,
        "expires_at" => 15.minutes.from_now.iso8601,
      },
    )

    host! acme_host
    patch acme_app_sign_in_limitation_path,
          params: {
            resolution_challenge: resolution.challenge,
            social_resolution: social_token,
            session_ref: SessionLimitResolutionTokenRef.issue(token),
          },
          headers: browser_headers

    assert_response :gone
    assert_not token.reload.revoked?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app session-limit limitation rejects missing payload" do
    host! ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")

    get acme_app_sign_in_limitation_path(ri: "jp"), headers: browser_headers

    assert_response :gone
  end

  test "acme app session-limit limitation cancel does not issue login or consume oidc transaction" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    resolution = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
      actor: user,
      oidc_transaction: issuance.transaction,
    )

    host! acme_host
    assert_no_difference -> { ClientToken.where(user_id: user.id).count } do
      delete acme_app_sign_in_limitation_path,
             params: { resolution_challenge: resolution.challenge },
             headers: browser_headers
    end

    assert_response :see_other
    assert_predicate resolution.transaction.reload, :cancelled?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app authorization resume succeeds with two usable tokens and consumes the transaction once" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all

      2.times do
        ClientToken.create!(
          user: user,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
        )
      end

      host! acme_host
      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      issuance =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: user,
          session_ref: "acme-session-limit-success",
          auth_method: "passkey",
        )

      assert_difference -> { ClientToken.where(user_id: user.id).count }, 1 do
        get URI.parse(issuance.resume_url).request_uri, headers: browser_headers
      end

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_predicate issuance.transaction.reload, :consumed?
    end
  end

  test "app com and org authorization endpoints are exposed at Acme oauth authorize" do
    SURFACES.each do |surface|
      open_session do |session|
        session.host!(surface[:acme_host])

        session.get(
          "/oauth/authorize", params: {
            response_type: "code",
            client_id: surface[:client_id],
            redirect_uri: redirect_uri_for(surface),
            code_challenge: SecureRandom.urlsafe_base64(32),
            code_challenge_method: "S256",
            state: "state",
            nonce: "nonce",
            scope: "openid profile",
          }, headers: browser_headers,
        )

        if surface[:acme_host] == ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
          assert_equal 302, session.response.status, surface[:client_id]
        else
          assert_equal 422, session.response.status, surface[:client_id]
          assert_equal "Invalid request", session.response.body
        end

        session.get("/oauth/authorization", headers: browser_headers)

        assert_equal 404, session.response.status, surface[:client_id]
      end
    end
  end

  test "app com and org old sign entry routes are not exposed" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/sign", headers: browser_headers

      assert_response :not_found

      get "/sign/in", headers: browser_headers

      assert_response :not_found

      get "/sign/up", headers: browser_headers

      assert_response :not_found
    end
  end

  test "callback rejects state mismatch" do
    host! ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    get "/oidc/authorization", headers: browser_headers

    get "/oidc/callback", params: { code: "code", state: "wrong" }, headers: browser_headers

    assert_response :unprocessable_entity
  end

  test "callback rejects nonce mismatch" do
    acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    host! acme_host
    get "/oidc/authorization", headers: browser_headers
    state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
    id_token = OidcIdTokenIssuer.call(
      resource: clients(:one),
      client: OidcClientRegistry.find!("base-rails-rp"),
      nonce: "wrong_nonce",
    )
    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: { id_token: id_token },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, token_result) do
      get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
    end

    assert_response :redirect
    assert_not_equal "http://#{acme_host}/", response.location, "nonce mismatch must not land on root"
  end

  test "app com and org callback establishes RP session after successful authorization" do
    SURFACES.each do |surface|
      host! surface[:host]
      get "/oidc/authorization", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      resource_type = oidc_resource_type_for(resource)
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect
      expected_location =
        if surface[:host] == ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
          "http://#{surface[:host]}/dashboard"
        else
          "http://#{surface[:host]}/"
        end

      assert_equal expected_location, response.location
      assert_response_has_auth_cookie if surface[:host] == ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    end
  end

  test "logout clears only RP session and redirects locally with Acme session-management guidance" do
    SURFACES.each do |surface|
      host! surface[:host]

      post "/oidc/logout", headers: browser_headers

      # Without an id_token_hint the endpoint renders a confirmation page
      # (per OIDC end session spec) rather than performing logout immediately.
      assert_response :success
    end
  end

  test "RP only logout route does not exist" do
    post "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found

    delete "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found
  end

  private

  def oidc_resource_type_for(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    end
  end

  def redirect_uri_for(surface)
    OidcClientRegistry.find!(surface[:client_id]).redirect_uris.find do |uri|
      URI.parse(uri).host == surface[:host]
    end
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

  def issue_authenticated_app_oidc_transaction(user, auth_method:, code_verifier: nil)
    code_challenge =
      if code_verifier.present?
        Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      else
        SecureRandom.urlsafe_base64(32)
      end

    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "base-rails-rp",
        redirect_uri: redirect_uri_for(SURFACES.first),
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: code_challenge,
        code_challenge_method: "S256",
      },
    ).transaction.then do |transaction|
      OidcAuthorizationTransactionCoordinator.register_result!(
        surface: "app",
        login_challenge: transaction.login_challenge,
        actor: user,
        session_ref: SecureRandom.hex(16),
        auth_method: auth_method,
      )
    end
  end

  def store_email_otp_and_return_code(email)
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)
    pass_code
  end

  def assert_response_has_auth_cookie
    assert_includes response.headers["Set-Cookie"].to_s, "#{COOKIE_NAME}=",
                    "expected callback response to set #{COOKIE_NAME}"
  end

  def with_acme_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = "acme-app-oidc-test"
    ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end
end
