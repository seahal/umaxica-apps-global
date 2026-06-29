# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcAuthorizationTransactionCoordinatorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = clients(:one)
    @params = {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end

  test "issue creates a pending transaction and resume url points to acme authorize" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params)

    assert_predicate issuance.transaction, :persisted?
    assert_equal "pending", issuance.transaction.status
    assert_equal "app", issuance.transaction.surface
    assert_equal "sign_in", issuance.transaction.intent

    uri = URI.parse(issuance.resume_url)

    assert_equal ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal issuance.transaction.login_challenge, Rack::Utils.parse_nested_query(uri.query)["login_challenge"]
  end

  test "register_result marks the transaction authenticated and consume makes it one time" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(surface: "app", intent: "sign_in", params: @params)

    result =
      OidcAuthorizationTransactionCoordinator.register_result!(
        surface: "app",
        login_challenge: issuance.transaction.login_challenge,
        actor: @client,
        session_ref: "session-1",
        auth_method: "passkey",
      )

    assert_predicate result.transaction, :authenticated?
    assert_equal @client.public_id, result.transaction.actor_ref

    consumed = OidcAuthorizationTransactionCoordinator.consume!(
      surface: "app",
      login_challenge: issuance.transaction.login_challenge,
    )

    assert_predicate consumed, :consumed?

    assert_raises(ArgumentError) do
      OidcAuthorizationTransactionCoordinator.consume!(
        surface: "app",
        login_challenge: issuance.transaction.login_challenge,
      )
    end
  end

  test "model_for raises on unsupported surface" do
    assert_raises(ArgumentError, match: /unsupported OIDC authorization surface/) do
      OidcAuthorizationTransactionCoordinator.model_for("unsupported")
    end
  end

  test "expired login challenge is rejected when registering ceremony result" do
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: @params,
        login_challenge_ttl: 1.second,
        now: Time.current,
      )

    travel 2.seconds do
      error =
        assert_raises(ArgumentError) do
          OidcAuthorizationTransactionCoordinator.register_result!(
            surface: "app",
            login_challenge: issuance.transaction.login_challenge,
            actor: @client,
            session_ref: "session-1",
            auth_method: "passkey",
          )
        end

      assert_equal "authorization transaction expired", error.message
    end
  end
end
