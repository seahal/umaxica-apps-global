# typed: false
# frozen_string_literal: true

require "test_helper"

# The OAuth authorization endpoint exists on all three base surfaces and each
# one owns its own realm, validator resource type, and error mapping. The app
# surface is covered by BaseOauthOidcAuthorityTest; these pin the spec-defined
# error responses of the corporate and staff surfaces.
class BaseOauthAuthorizationSurfacesTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "com authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_match(/openid/, response.parsed_body.fetch("error_description"))
  end

  test "org authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects a redirect_uri that is not registered for the corporate realm" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host,
      **authorize_params(realm: "visitor").merge(redirect_uri: "https://attacker.example/callback"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects an unknown login challenge as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(host: host, login_challenge: "no-such-challenge"),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "com authorize resumes an authenticated login challenge exactly once" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-resume-session", auth_method: "passkey",
    )

    get base_com_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?

    get base_com_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction already consumed", response.parsed_body.fetch("error_description")
  end

  test "org authorize resumes an authenticated login challenge exactly once" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "org", login_challenge: issuance.transaction.login_challenge,
      actor: operators(:one), session_ref: "org-resume-session", auth_method: "passkey",
    )

    get base_org_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?

    get base_org_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction already consumed", response.parsed_body.fetch("error_description")
  end

  test "com authorize refuses a login challenge that no sign-in has completed" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )

    get base_com_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction is not ready", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?
  end

  test "org authorize refuses a login challenge that no sign-in has completed" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )

    get base_org_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction is not ready", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?
  end

  test "com authorize refuses an expired login challenge" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
      login_challenge_ttl: 1.second, now: Time.current,
    )

    travel 2.seconds do
      get base_com_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
          headers: { "Host" => host }
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body.fetch("error_description")
  end

  test "org authorize refuses an expired login challenge" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
      login_challenge_ttl: 1.second, now: Time.current,
    )

    travel 2.seconds do
      get base_org_oauth_authorization_url(host: host, login_challenge: issuance.transaction.login_challenge),
          headers: { "Host" => host }
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body.fetch("error_description")
  end

  private

  def authorize_params(realm:)
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid",
    }
  end
end
