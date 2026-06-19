# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionableTest < ActiveSupport::TestCase
  test "create_transaction! persists a transaction and authorize_params mirrors the public contract" do
    transaction = create_transaction(ClientOidcAuthorizationTransaction, surface: "app")

    assert_equal "pending", transaction.status
    assert_equal(
      {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: "https://example.test/callback",
        scope: "openid email",
        state: "state-one",
        nonce: "nonce-one",
        code_challenge: "challenge-one",
        code_challenge_method: "S256",
      },
      transaction.authorize_params,
    )
  end

  test "register_authentication! and consume! advance the transaction state" do
    now = Time.zone.local(2026, 6, 19, 14, 0, 0)
    transaction = create_transaction(VisitorOidcAuthorizationTransaction, surface: "com")

    travel_to now do
      transaction = transaction.register_authentication!(
        actor_ref: "visitor-1",
        session_ref: "session-1",
        auth_method: "pwd",
        acr: "",
      )

      assert_predicate transaction, :authenticated?
      assert_equal "aal1", transaction.acr
      assert_equal "visitor-1", transaction.actor_ref

      transaction = transaction.consume!

      assert_predicate transaction, :consumed?
      assert_equal now, transaction.consumed_at
    end
  end

  test "expired or consumed transactions reject further progress" do
    expired = create_transaction(OperatorOidcAuthorizationTransaction, surface: "org")
    expired.update!(expires_at: 1.minute.ago)

    error =
      assert_raises(ArgumentError) do
        expired.register_authentication!(
          actor_ref: "operator-1",
          session_ref: "session-1",
          auth_method: "pwd",
          acr: "aal2",
        )
      end
    assert_match(/expired/, error.message)

    transaction = create_transaction(OperatorOidcAuthorizationTransaction, surface: "org", unique: "two")
    transaction = transaction.register_authentication!(
      actor_ref: "operator-1",
      session_ref: "session-1",
      auth_method: "pwd",
      acr: "aal2",
    )
    transaction.consume!

    error = assert_raises(ArgumentError) { transaction.consume! }
    assert_match(/not authenticated/, error.message)
  end

  test "transaction surface must match the owning class" do
    {
      ClientOidcAuthorizationTransaction => "org",
      OperatorOidcAuthorizationTransaction => "com",
      VisitorOidcAuthorizationTransaction => "app",
    }.each do |transaction_class, invalid_surface|
      transaction = transaction_class.new(surface: invalid_surface)

      assert_not transaction.valid?
      assert_includes transaction.errors[:surface], "does not match transaction store"
    end
  end

  private

  def create_transaction(transaction_class, surface:, unique: "one")
    transaction_class.create_transaction!(
      surface: surface,
      intent: "sign_in",
      client_id: "core-next-rp",
      redirect_uri: "https://example.test/callback",
      response_type: "code",
      scope: "openid email",
      state: "state-#{unique}",
      nonce: "nonce-#{unique}",
      code_challenge: "challenge-#{unique}",
      code_challenge_method: "S256",
      login_challenge: "login-#{unique}",
      login_challenge_expires_at: 5.minutes.from_now,
      expires_at: 10.minutes.from_now,
    )
  end
end
