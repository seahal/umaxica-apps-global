# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySecretCredentialCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels,
           :client_secret_credential_statuses, :client_secret_credential_kinds, :client_email_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @client.client_secret_credentials.destroy_all
    ClientEmail.create!(
      user: @client,
      address: "secret-ceremony-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    IdentitySecretCredentialCeremonyCandidate.find_each(&:destroy!)
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = issue_grant
      grant = IdentitySecretCredentialCeremonyGrant.decode(
        issuance.grant,
        issuer_id: IdentitySecretCredentialCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
    end
  end

  test "valid result consumes once and commits secret credential under acme authority" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)

      assert_difference -> { @client.client_secret_credentials.count }, 1 do
        assert_difference -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: @client.id,
            subject_type: "ClientSecretCredential",
            event_id: ClientChronicleEvent::USER_SECRET_CREATED,
          ).count
        }, 1 do
          commit = IdentitySecretCredentialCeremonyFinalCommitter.call!(
            result_token: result_token,
            actor: @client,
            session_ref: @session_ref,
            surface: "app",
            ip_address: "127.0.0.1",
            user_agent: "Rails test",
            now: @now,
          )

          assert_equal "Ceremony secret credential", commit.secret_credential.name
          assert commit.secret_credential.authenticate(raw_secret_credential)
        end
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) { IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref) }
      assert_not_nil IdentitySecretCredentialCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )
      end
    end
  end

  test "result payload and transaction table do not expose secret credential material" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)
      payload = IdentitySecretCredentialCeremonyContract.decode_unverified_payload(result_token)

      assert_equal candidate.ref, payload["credential_candidate_ref"]
      assert_equal candidate.digest, payload["credential_candidate_digest"]
      assert_not_includes payload.to_json, raw_secret_credential
      assert_not_includes payload.to_json, candidate.password_digest
      assert_not payload.key?("password")
      assert_not payload.key?("password_digest")
      assert_not payload.key?("raw_secret_credential")
      assert_not_includes encrypted_secret_candidate_password_digest(candidate.ref), candidate.password_digest
    end

    forbidden_columns = %w(
      private_key raw_password password password_digest session_token refresh_token otp
      secret_credential_secret secret_key first_token
    )

    assert_empty ClientSecretCredentialCeremonyTransaction.column_names & forbidden_columns
    assert_empty VisitorSecretCredentialCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorSecretCredentialCeremonyTransaction.column_names & forbidden_columns
  end

  test "candidate store rejects expired deleted malformed records and does not call Rails cache" do
    travel_to @now do
      cache = Minitest::Mock.new

      Rails.stub(:cache, cache) do
        issue_grant
        expired = store_candidate(expires_at: @now - 1.second)
        deleted = store_candidate(expires_at: @now + 5.minutes)
        IdentitySecretCredentialCeremonyCandidateStore.delete(deleted.ref)
        malformed = IdentitySecretCredentialCeremonyCandidate.create!(
          ref: SecureRandom.uuid,
          digest: "digest",
          surface: "app",
          actor_ref: @client.public_id,
          session_ref: @session_ref,
          transaction_id: "txn-malformed",
          operation: "enrollment",
          password_digest: password_digest,
          name: "Malformed",
          enabled: true,
          expires_at: @now + 5.minutes,
        )
        malformed.surface = "invalid-surface"
        malformed.save!(validate: false)

        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(expired.ref)
        end
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(deleted.ref)
        end
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
          IdentitySecretCredentialCeremonyCandidateStore.fetch!(malformed.ref)
        end
      end

      cache.verify
    end
  end

  test "candidate and result bindings reject wrong actor and session" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)

      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: clients(:two),
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: "wrong-session",
          surface: "app",
          now: @now,
        )
      end
    end
  end

  test "purger removes only retained expired and consumed transactions" do
    travel_to @now do
      active = issue_grant.transaction
      expired_old = IdentitySecretCredentialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-expired",
        operation: "enrollment",
        expires_at: @now - 8.days,
        now: @now - 9.days,
      )
      consumed_old = IdentitySecretCredentialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-consumed",
        operation: "enrollment",
        expires_at: @now + 1.hour,
        now: @now - 9.days,
      )
      consumed_old.update!(
        status: SecretCredentialCeremonyTransactionable::STATUS_CONSUMED, result_jti: SecureRandom.uuid,
        consumed_at: @now - 8.days,
      )

      counts = IdentitySecretCredentialCeremonyTransactionPurger.new(now: @now).call

      assert_equal 2, counts.fetch(:app)
      assert ClientSecretCredentialCeremonyTransaction.exists?(active.id)
      assert_not ClientSecretCredentialCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientSecretCredentialCeremonyTransaction.exists?(consumed_old.id)
    end
  end

  test "replay store rejects invalid surface" do
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyReplayStore.for("invalid-surface")
    end
  end

  test "replay store raises error on missing transaction" do
    store = IdentitySecretCredentialCeremonyReplayStore.for("app")
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      store.find_transaction!("non-existent-id")
    end
  end

  private

  def issue_grant
    IdentitySecretCredentialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "enrollment",
      now: @now,
    )
  end

  def store_candidate(expires_at:)
    IdentitySecretCredentialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      transaction_id: ClientSecretCredentialCeremonyTransaction.last.transaction_id,
      operation: "enrollment",
      password_digest: password_digest,
      name: "Ceremony secret credential",
      enabled: true,
      expires_at: expires_at,
    )
  end

  def raw_secret_credential
    @raw_secret_credential ||= ClientSecretCredential.generate_raw_secret_credential
  end

  def password_digest
    record = ClientSecretCredential.new(name: "Candidate")
    record.password = raw_secret_credential
    record.password_digest
  end

  def issue_result(grant_token, candidate)
    IdentitySecretCredentialCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "enrollment",
      now: @now,
    )
  end

  def encrypted_secret_candidate_password_digest(ref)
    IdentitySecretCredentialCeremonyCandidate.connection.select_value(
      IdentitySecretCredentialCeremonyCandidate.sanitize_sql_array(
        [
          /SELECT password_digest FROM identity_secret_credential_ceremony_candidates WHERE ref/,
          ref,
        ],
      ),
    ).to_s
  end
end
