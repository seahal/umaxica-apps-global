# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::EmailCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_email_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = Identity::EmailCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        now: @now,
      )

      grant = Identity::EmailCeremony::Grant.decode(
        issuance.grant,
        issuer_id: Identity::EmailCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
    end
  end

  test "valid result consumes once and commits email under acme authority" do
    travel_to @now do
      email = create_unverified_client_email!("email-ceremony-commit@example.com")
      issuance = Identity::EmailCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        email_candidate_ref: email.public_id,
        normalized_email_digest: email.address_digest,
        now: @now,
      )
      result_token = Identity::EmailCeremony::ResultIssuer.issue!(
        grant_token: issuance.grant,
        candidate: email,
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        now: @now,
      )

      assert_difference(
        -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: @client.id,
            subject_type: "Client",
            subject_id: @client.id,
            event_id: ClientChronicleEvent::EMAIL_REGISTERED,
          ).count
        },
        1,
      ) do
        commit = Identity::EmailCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )

        assert_equal email.public_id, commit.email.public_id
      end

      assert_equal ClientEmailStatus::VERIFIED, email.reload.user_email_status_id
      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(Identity::EmailCeremony::Error) do
        Identity::EmailCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end
    end
  end

  test "result consumer rejects wrong actor session surface grant and expired transaction" do
    travel_to @now do
      email = create_unverified_client_email!("email-ceremony-reject@example.com")
      issuance = Identity::EmailCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        email_candidate_ref: email.public_id,
        normalized_email_digest: email.address_digest,
        now: @now,
      )

      wrong_session = Identity::EmailCeremony::Result.issue(
        result_claims(issuance.transaction, email).merge("session_ref" => "wrong-session"),
        issuer_id: Identity::EmailCeremony::Contract.sign_issuer_id("app"),
        now: @now,
      )

      assert_raises(Identity::EmailCeremony::Error) do
        Identity::EmailCeremony::FinalCommitter.call!(
          result_token: wrong_session,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end

      issuance.transaction.update!(expires_at: @now - 1.minute)
      expired = Identity::EmailCeremony::Result.issue(
        result_claims(issuance.transaction, email).merge(
          "expires_at" => (@now + 10.minutes).to_i,
          "exp" => (@now + 10.minutes).to_i,
        ),
        issuer_id: Identity::EmailCeremony::Contract.sign_issuer_id("app"),
        now: @now,
      )

      assert_raises(Identity::EmailCeremony::Error) do
        Identity::EmailCeremony::FinalCommitter.call!(
          result_token: expired,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end
    end
  end

  test "purger removes only old expired or consumed records" do
    old_expired = create_transaction("old-expired", expires_at: 8.days.ago)
    recent_expired = create_transaction("recent-expired", expires_at: 1.hour.ago)
    active = create_transaction("active", expires_at: 1.hour.from_now)
    old_consumed = create_transaction("old-consumed", expires_at: 1.hour.from_now)
    old_consumed.update!(
      status: EmailCeremonyTransactionable::STATUS_CONSUMED, result_jti: "result-old",
      consumed_at: 8.days.ago,
    )

    counts = Identity::EmailCeremony::TransactionPurger.new(now: Time.current).call

    assert_equal 2, counts[:app]
    assert_not ClientEmailCeremonyTransaction.exists?(old_expired.id)
    assert_not ClientEmailCeremonyTransaction.exists?(old_consumed.id)
    assert ClientEmailCeremonyTransaction.exists?(recent_expired.id)
    assert ClientEmailCeremonyTransaction.exists?(active.id)
  end

  test "transaction tables do not persist forbidden secret fields" do
    forbidden_columns = %w(raw_address email_address otp otp_digest otp_private_key session_token refresh_token)

    assert_empty ClientEmailCeremonyTransaction.column_names & forbidden_columns
    assert_empty VisitorEmailCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorEmailCeremonyTransaction.column_names & forbidden_columns
  end

  private

  def create_unverified_client_email!(address)
    ClientEmail.create!(
      user: @client,
      address: address,
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
  end

  def create_transaction(identifier, expires_at:)
    ClientEmailCeremonyTransaction.create_transaction!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: "#{@session_ref}-#{identifier}",
      operation: "registration",
      transaction_id: "email-txn-#{identifier}",
      grant_jti: "email-grant-#{identifier}",
      expires_at: expires_at,
    )
  end

  def result_claims(transaction, email)
    {
      "typ" => Identity::EmailCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::EmailCeremony::Contract.sign_issuer("app"),
      "aud" => Identity::EmailCeremony::Contract.acme_audience("app"),
      "purpose" => Identity::EmailCeremony::Result::PURPOSE,
      "surface" => "app",
      "actor_ref" => transaction.actor_ref,
      "session_ref" => transaction.session_ref,
      "transaction_id" => transaction.transaction_id,
      "grant_jti" => transaction.grant_jti,
      "result_jti" => SecureRandom.uuid,
      "operation" => transaction.operation,
      "proof_method" => Identity::EmailCeremony::Result::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => email.public_id,
      "expires_at" => transaction.expires_at.to_i,
      "iat" => @now.to_i,
      "exp" => transaction.expires_at.to_i,
      "email_candidate_ref" => email.public_id,
      "normalized_email_digest" => email.address_digest,
    }
  end
end
