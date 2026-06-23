# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityTotpCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels,
           :client_totp_credential_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @client.client_totp_credentials.destroy_all
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    IdentityTotpCeremonyCandidate.find_each(&:destroy!)
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = issue_grant
      grant = IdentityTotpCeremonyGrant.decode(
        issuance.grant,
        issuer_id: IdentityTotpCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
    end
  end

  test "valid result consumes once and commits totp under acme authority" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)

      assert_difference -> { @client.client_totp_credentials.count }, 1 do
        assert_difference -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: @client.id,
            subject_type: "Client",
            subject_id: @client.id,
            event_id: ClientChronicleEvent::TOTP_ENABLED,
          ).count
        }, 1 do
          commit = IdentityTotpCeremonyFinalCommitter.call!(
            result_token: result_token,
            actor: @client,
            session_ref: @session_ref,
            surface: "app",
            ip_address: "127.0.0.1",
            user_agent: "Rails test",
            now: @now,
          )

          assert_equal "Ceremony TOTP", commit.totp.title
          assert_equal candidate.private_key, commit.totp.private_key
        end
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(IdentityTotpCeremonyContract::Error) { IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref) }
      assert_not_nil IdentityTotpCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpCeremonyFinalCommitter.call!(
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

  test "result payload and transaction table do not expose totp secret material" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)
      payload = IdentityTotpCeremonyContract.decode_unverified_payload(result_token)

      assert_equal candidate.ref, payload["credential_candidate_ref"]
      assert_equal candidate.digest, payload["credential_candidate_digest"]
      assert_not_includes payload.to_json, candidate.private_key
      assert_not payload.key?("private_key")
      assert_not payload.key?("totp_secret")
      assert_not payload.key?("first_token")
      assert_not_includes encrypted_totp_candidate_private_key(candidate.ref), candidate.private_key
    end

    forbidden_columns = %w(
      private_key raw_password password password_digest session_token refresh_token otp
      totp_secret secret_key first_token
    )

    assert_empty ClientTotpCeremonyTransaction.column_names & forbidden_columns
  end

  test "candidate store rejects expired deleted malformed records and does not call Rails cache" do
    travel_to @now do
      cache = Minitest::Mock.new

      Rails.stub(:cache, cache) do
        expired = store_candidate(expires_at: @now - 1.second)
        deleted = store_candidate(expires_at: @now + 5.minutes)
        IdentityTotpCeremonyCandidateStore.delete(deleted.ref)
        malformed = IdentityTotpCeremonyCandidate.create!(
          ref: SecureRandom.uuid,
          digest: "digest",
          surface: "app",
          actor_ref: @client.public_id,
          session_ref: @session_ref,
          private_key: "JBSWY3DPEHPK3PXP",
          last_otp_at: @now,
          expires_at: @now + 5.minutes,
        )
        malformed.surface = "invalid-surface"
        malformed.save!(validate: false)

        assert_raises(IdentityTotpCeremonyContract::Error) { IdentityTotpCeremonyCandidateStore.fetch!(expired.ref) }
        assert_raises(IdentityTotpCeremonyContract::Error) { IdentityTotpCeremonyCandidateStore.fetch!(deleted.ref) }
        assert_raises(IdentityTotpCeremonyContract::Error) { IdentityTotpCeremonyCandidateStore.fetch!(malformed.ref) }
      end

      cache.verify
    end
  end

  test "candidate and result bindings reject wrong actor and session" do
    travel_to @now do
      issuance = issue_grant
      candidate = store_candidate(expires_at: issuance.transaction.expires_at)
      result_token = issue_result(issuance.grant, candidate)

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: clients(:two),
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end
      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpCeremonyFinalCommitter.call!(
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
      expired_old = IdentityTotpCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-expired",
        operation: "registration",
        expires_at: @now - 8.days,
        now: @now - 9.days,
      )
      consumed_old = IdentityTotpCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-consumed",
        operation: "registration",
        expires_at: @now + 1.hour,
        now: @now - 9.days,
      )
      consumed_old.update!(
        status: TotpCeremonyTransactionable::STATUS_CONSUMED, result_jti: SecureRandom.uuid,
        consumed_at: @now - 8.days,
      )

      counts = IdentityTotpCeremonyTransactionPurger.new(now: @now).call

      assert_equal 2, counts.fetch(:app)
      assert ClientTotpCeremonyTransaction.exists?(active.id)
      assert_not ClientTotpCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientTotpCeremonyTransaction.exists?(consumed_old.id)
    end
  end

  test "active_at scope returns only non-expired pending transactions" do
    travel_to @now do
      active = issue_grant.transaction
      expired = IdentityTotpCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-scope-expired",
        operation: "registration",
        expires_at: @now - 1.hour,
        now: @now - 2.hours,
      )

      active_at = ClientTotpCeremonyTransaction.active_at(@now)

      assert_includes active_at, active
      assert_not_includes active_at, expired
    end
  end

  test "consume_result raises when result_jti collides with an existing consumed transaction" do
    travel_to @now do
      first = issue_grant.transaction
      first.consume_result!(result_jti: "totp-colliding", consumed_at: @now)

      second = IdentityTotpCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-dup-second",
        operation: "registration",
        expires_at: @now + 1.hour,
        now: @now,
      )

      assert_raises(IdentityTotpCeremonyContract::Error) do
        second.consume_result!(result_jti: "totp-colliding", consumed_at: @now)
      end
    end
  end

  test "surface validation rejects surface that does not match ceremony surface" do
    txn = ClientTotpCeremonyTransaction.new(
      surface: "com",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "registration",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
    )

    assert_not txn.valid?
    assert_includes txn.errors.attribute_names, :surface
  end

  test "consumed transaction without result_jti is invalid" do
    txn = ClientTotpCeremonyTransaction.new(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "registration",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
      status: TotpCeremonyTransactionable::STATUS_CONSUMED,
    )

    assert_not txn.valid?
    assert_includes txn.errors.attribute_names, :result_jti
  end

  test "candidate store consume marks candidate as consumed and returns candidate value" do
    travel_to @now do
      candidate = store_candidate(expires_at: @now + 5.minutes)
      consumed = IdentityTotpCeremonyCandidateStore.consume!(candidate.ref)

      assert_equal candidate.ref, consumed.ref
      assert_not_nil IdentityTotpCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
    end
  end

  private

  def issue_grant
    IdentityTotpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "registration",
      now: @now,
    )
  end

  def store_candidate(expires_at:)
    IdentityTotpCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      private_key: "JBSWY3DPEHPK3PXP",
      title: "Ceremony TOTP",
      last_otp_at: @now,
      expires_at: expires_at,
    )
  end

  def issue_result(grant_token, candidate)
    IdentityTotpCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "registration",
      now: @now,
    )
  end

  def encrypted_totp_candidate_private_key(ref)
    IdentityTotpCeremonyCandidate.connection.select_value(
      IdentityTotpCeremonyCandidate.sanitize_sql_array(
        [
          # rubocop:disable I18n/RailsI18n/DecorateString
          "SELECT private_key FROM identity_totp_ceremony_candidates WHERE ref = ?",
          # rubocop:enable I18n/RailsI18n/DecorateString
          ref,
        ],
      ),
    ).to_s
  end
end
