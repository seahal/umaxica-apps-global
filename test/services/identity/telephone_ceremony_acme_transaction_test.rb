# frozen_string_literal: true

require "test_helper"

class Identity::TelephoneCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.local(2026, 1, 2, 3, 4, 5)
    @transaction = ClientTelephoneCeremonyTransaction.create_transaction!(
      surface: "app",
      actor_ref: "actor-client-1",
      session_ref: "session-1",
      operation: "registration",
      transaction_id: "txn-1",
      grant_jti: "grant-1",
      normalized_number_digest: "digest-1",
      now: @now,
      expires_at: @now + 10.minutes,
    )
    @replay_store = Identity::TelephoneCeremony::ReplayStore.for("app")
  end

  teardown do
    travel_back
  end

  test "acme transaction creates a valid telephone ceremony grant" do
    travel_to(@now) do
      issuance = Identity::TelephoneCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: "actor-client-2",
        session_ref: "session-2",
        operation: "registration",
        normalized_number_digest: "digest-2",
        expires_at: @now + 10.minutes,
        now: @now,
      )

      grant = Identity::TelephoneCeremony::Grant.decode(
        issuance.grant,
        issuer_id: Identity::TelephoneCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )

      assert_predicate issuance.transaction, :persisted?
      assert_equal Identity::TelephoneCeremony::Contract.acme_issuer("app"), grant["iss"]
      assert_equal Identity::TelephoneCeremony::Contract.sign_audience("app"), grant["aud"]
      assert_equal Identity::TelephoneCeremony::Grant::PURPOSE, grant["purpose"]
      assert_equal "app", grant["surface"]
      assert_equal "registration", grant["operation"]
      assert_equal "actor-client-2", grant["actor_ref"]
      assert_equal "session-2", grant["session_ref"]
      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal 10.minutes.from_now.to_i, grant["exp"]
    end
  end

  test "acme result consumer accepts valid result once and marks only skeleton transaction state" do
    travel_to(@now) do
      token = issue_result_token(valid_result_claims)
      consumption = nil

      assert_no_telephone_account_mutation do
        consumption = consumer.call(token)
      end

      assert_predicate consumption.transaction, :consumed?
      assert_equal "result-1", consumption.transaction.result_jti
      assert_equal "result-1", @transaction.reload.result_jti
      assert_equal @now.to_i, @transaction.consumed_at.to_i
      assert_equal "result-1", consumption.result["result_jti"]
      assert @replay_store.consumed?("result-1")
    end
  end

  test "acme result consumer rejects replayed result" do
    travel_to(@now) do
      token = issue_result_token(valid_result_claims)

      consumer.call(token)

      assert_ceremony_error(/already consumed/) { consumer.call(token) }
    end
  end

  test "acme durable store rejects stale near concurrent consume attempts" do
    travel_to(@now) do
      token = issue_result_token(valid_result_claims)
      first_reader = ClientTelephoneCeremonyTransaction.find_by!(transaction_id: "txn-1")
      second_reader = ClientTelephoneCeremonyTransaction.find_by!(transaction_id: "txn-1")

      Identity::TelephoneCeremony::ResultConsumer.new(transaction: first_reader, now: @now).call(token)

      assert_ceremony_error(/already consumed/) do
        Identity::TelephoneCeremony::ResultConsumer.new(transaction: second_reader, now: @now).call(token)
      end
    end
  end

  test "acme durable store rejects duplicate transaction grant and result identifiers" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-client-2",
        session_ref: "session-2",
        operation: "registration",
        transaction_id: "txn-1",
        grant_jti: SecureRandom.uuid,
        expires_at: 10.minutes.from_now,
        created_at: Time.current,
        updated_at: Time.current,
      ).save!(validate: false)
    end

    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientTelephoneCeremonyTransaction.new(
        surface: "app",
        actor_ref: "actor-client-2",
        session_ref: "session-2",
        operation: "registration",
        transaction_id: SecureRandom.uuid,
        grant_jti: "grant-1",
        expires_at: 10.minutes.from_now,
        created_at: Time.current,
        updated_at: Time.current,
      ).save!(validate: false)
    end

    travel_to(@now) do
      Identity::TelephoneCeremony::ResultConsumer.new(transaction: @transaction, now: @now).call(
        issue_result_token(valid_result_claims.merge("result_jti" => "duplicate-result")),
      )
      second = ClientTelephoneCeremonyTransaction.create_transaction!(
        surface: "app",
        actor_ref: "actor-client-1",
        session_ref: "session-1",
        operation: "registration",
        transaction_id: "txn-duplicate",
        grant_jti: "grant-duplicate",
        now: @now,
        expires_at: @now + 10.minutes,
      )
      duplicate = issue_result_token(
        valid_result_claims.merge(
          "transaction_id" => "txn-duplicate",
          "grant_jti" => "grant-duplicate",
          "result_jti" => "duplicate-result",
        ),
      )

      assert_ceremony_error(/already been consumed/) do
        Identity::TelephoneCeremony::ResultConsumer.new(transaction: second, now: @now).call(duplicate)
      end
    end
  end

  test "acme result consumer rejects expired and tampered result tokens" do
    travel_to(@now) do
      expired = sign_result_payload(
        valid_result_claims.merge(
          "expires_at" => 1.minute.ago.to_i,
          "exp" => 1.minute.ago.to_i,
        ),
      )
      assert_ceremony_error(/token verification failed|expires_at is expired/) { consumer.call(expired) }

      tampered = tamper_payload(issue_result_token(valid_result_claims), "actor_ref" => "actor-client-2")
      assert_ceremony_error(/token verification failed/) { consumer.call(tampered) }
    end
  end

  test "acme result consumer rejects wrong audience purpose surface actor session transaction and grant" do
    travel_to(@now) do
      {
        "aud" => Identity::TelephoneCeremony::Contract.acme_audience("com"),
        "purpose" => "wrong",
        "surface" => "com",
        "actor_ref" => "actor-client-2",
        "session_ref" => "session-2",
        "transaction_id" => "txn-2",
        "grant_jti" => "grant-2",
      }.each do |claim, value|
        token = sign_result_payload(valid_result_claims.merge(claim => value))
        assert_ceremony_error(/token verification failed|#{claim} does not match transaction|#{claim} is invalid/) do
          consumer.call(token)
        end
      end
    end
  end

  test "acme result consumer rejects wrong operation and forbidden claims" do
    travel_to(@now) do
      wrong_operation = issue_result_token(valid_result_claims.merge("operation" => "replacement"))
      assert_ceremony_error(/operation does not match transaction/) { consumer.call(wrong_operation) }

      %w(otp verifier_digest session_token refresh_token telephone_number recent_auth sudo
         step_up_freshness).each do |claim|
        token = sign_result_payload(valid_result_claims.merge(claim => "secret"))
        assert_ceremony_error(/forbidden claims: #{claim}/) { consumer.call(token) }
      end
    end
  end

  test "transaction skeleton validates required authority bindings" do
    missing_actor = ClientTelephoneCeremonyTransaction.new(
      surface: "app",
      actor_ref: "",
      session_ref: "session-1",
      operation: "registration",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
    )

    assert_not missing_actor.valid?
    assert_includes missing_actor.errors.attribute_names, :actor_ref

    wrong_surface = ClientTelephoneCeremonyTransaction.new(
      surface: "com",
      actor_ref: "actor-client-1",
      session_ref: "session-1",
      operation: "registration",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
    )

    assert_not wrong_surface.valid?
    assert_includes wrong_surface.errors.attribute_names, :surface

    wrong_operation = ClientTelephoneCeremonyTransaction.new(
      surface: "app",
      actor_ref: "actor-client-1",
      session_ref: "session-1",
      operation: "delete",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
    )

    assert_not wrong_operation.valid?
    assert_includes wrong_operation.errors.attribute_names, :operation
  end

  test "durable transaction schema does not persist ceremony secrets or tokens" do
    forbidden_columns = %w(
      auth_token authorization downstream_token otp otp_digest otp_private_key raw_number recent_auth refresh_token
      session_token step_up_freshness sudo telephone_number token verifier_digest verifier_secret
    )

    assert_empty ClientTelephoneCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorTelephoneCeremonyTransaction.column_names & forbidden_columns
    assert_empty VisitorTelephoneCeremonyTransaction.column_names & forbidden_columns
  end

  test "telephone ceremony transaction scopes classify active expired consumed and purgeable rows" do
    active = create_app_transaction("scope-active", expires_at: @now + 10.minutes)
    expired_recent = create_app_transaction("scope-expired-recent", expires_at: @now - 1.hour)
    expired_old = create_app_transaction("scope-expired-old", expires_at: @now - 8.days)
    consumed_recent = create_app_transaction("scope-consumed-recent", expires_at: @now + 10.minutes)
    consumed_old = create_app_transaction("scope-consumed-old", expires_at: @now + 10.minutes)
    consumed_recent.consume_result!(result_jti: "scope-result-recent", consumed_at: @now - 1.hour)
    consumed_old.consume_result!(result_jti: "scope-result-old", consumed_at: @now - 8.days)

    assert_includes ClientTelephoneCeremonyTransaction.active_at(@now), active
    assert_not_includes ClientTelephoneCeremonyTransaction.active_at(@now), expired_recent
    assert_includes ClientTelephoneCeremonyTransaction.expired_at(@now), expired_recent
    assert_includes ClientTelephoneCeremonyTransaction.consumed, consumed_recent.reload
    assert_includes ClientTelephoneCeremonyTransaction.purgeable_at(@now), expired_old
    assert_includes ClientTelephoneCeremonyTransaction.purgeable_at(@now), consumed_old.reload
    assert_not_includes ClientTelephoneCeremonyTransaction.purgeable_at(@now), active
    assert_not_includes ClientTelephoneCeremonyTransaction.purgeable_at(@now), expired_recent
    assert_not_includes ClientTelephoneCeremonyTransaction.purgeable_at(@now), consumed_recent.reload
  end

  test "telephone ceremony transaction purger deletes only purgeable rows across surfaces" do
    app_old = create_app_transaction("purge-app-old", expires_at: @now - 8.days)
    app_active = create_app_transaction("purge-app-active", expires_at: @now + 10.minutes)
    app_recent = create_app_transaction("purge-app-recent", expires_at: @now - 1.hour)
    com_old = create_transaction(
      VisitorTelephoneCeremonyTransaction,
      "purge-com-old",
      surface: "com",
      expires_at: @now - 8.days,
    )
    org_consumed_old = create_transaction(
      OperatorTelephoneCeremonyTransaction,
      "purge-org-consumed-old",
      surface: "org",
      expires_at: @now + 10.minutes,
    )
    org_consumed_old.consume_result!(result_jti: "purge-org-result-old", consumed_at: @now - 8.days)

    counts = nil
    assert_no_telephone_account_mutation do
      counts = Identity::TelephoneCeremony::TransactionPurger.new(now: @now, batch_size: 2).call
    end

    assert_equal({ app: 1, com: 1, org: 1 }, counts)
    assert_not ClientTelephoneCeremonyTransaction.exists?(app_old.id)
    assert_not VisitorTelephoneCeremonyTransaction.exists?(com_old.id)
    assert_not OperatorTelephoneCeremonyTransaction.exists?(org_consumed_old.id)
    assert ClientTelephoneCeremonyTransaction.exists?(app_active.id)
    assert ClientTelephoneCeremonyTransaction.exists?(app_recent.id)
    assert_equal({ app: 0, com: 0, org: 0 }, Identity::TelephoneCeremony::TransactionPurger.new(now: @now).call)
  end

  test "telephone ceremony transaction purge job delegates to retention purger" do
    create_app_transaction("job-purge-old", expires_at: @now - 8.days)

    TelephoneCeremonyTransactionPurgeJob.perform_now(batch_size: 1)

    assert_equal 0, ClientTelephoneCeremonyTransaction.where(transaction_id: "job-purge-old").count
  end

  test "result consumer rejects expired consumed and purged transactions" do
    expired = create_app_transaction("consumer-expired", expires_at: @now - 1.minute)
    consumed = create_app_transaction("consumer-consumed", expires_at: @now + 10.minutes)
    purged = create_app_transaction("consumer-purged", expires_at: @now - 8.days)
    consumed.consume_result!(result_jti: "consumer-consumed-result", consumed_at: @now)
    Identity::TelephoneCeremony::TransactionPurger.new(now: @now).call

    assert_ceremony_error(/transaction is expired/) do
      Identity::TelephoneCeremony::ResultConsumer.new(transaction: expired, now: @now).call(
        issue_result_token(valid_result_claims_for(expired, result_jti: "consumer-expired-result")),
      )
    end
    assert_ceremony_error(/already consumed/) do
      Identity::TelephoneCeremony::ResultConsumer.new(transaction: consumed, now: @now).call(
        issue_result_token(valid_result_claims_for(consumed, result_jti: "consumer-consumed-replay")),
      )
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      ClientTelephoneCeremonyTransaction.find(purged.id)
    end
    valid = create_app_transaction("consumer-valid", expires_at: @now + 10.minutes)

    consumption = Identity::TelephoneCeremony::ResultConsumer.new(transaction: valid, now: @now).call(
      issue_result_token(valid_result_claims_for(valid, result_jti: "consumer-valid-result")),
    )

    assert_predicate consumption.transaction, :consumed?
  end

  test "result issuer and final committer move app telephone final verification to acme" do
    travel_to(@now) do
      user = clients(:one)
      telephone = ClientTelephone.create!(
        user: user,
        raw_number: "+10000009100",
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
        otp_private_key: "secret_credential",
        otp_expires_at: 10.minutes.from_now,
      )
      issuance = Identity::TelephoneCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: user.public_id,
        session_ref: "session-app-commit",
        operation: "registration",
        telephone_candidate_ref: telephone.public_id,
        normalized_number_digest: telephone.number_digest,
        now: @now,
      )
      result_token = Identity::TelephoneCeremony::ResultIssuer.issue!(
        grant_token: issuance.grant,
        candidate: telephone,
        surface: "app",
        actor_ref: user.public_id,
        session_ref: "session-app-commit",
        operation: "registration",
        now: @now,
      )

      assert_difference(
        -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: user.id,
            event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
          ).count
        },
        1,
      ) do
        commit = Identity::TelephoneCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: user,
          session_ref: "session-app-commit",
          surface: "app",
          now: @now,
        )

        assert_equal telephone.id, commit.telephone.id
        assert_equal ClientTelephoneStatus::VERIFIED, telephone.reload.user_telephone_status_id
        assert_equal issuance.transaction.transaction_id, commit.transaction.transaction_id
      end
    end
  end

  test "final committer rejects replay and wrong session without changing telephone state" do
    travel_to(@now) do
      user = clients(:one)
      telephone = ClientTelephone.create!(
        user: user,
        raw_number: "+10000009101",
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
        otp_private_key: "secret_credential",
        otp_expires_at: 10.minutes.from_now,
      )
      issuance = Identity::TelephoneCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: user.public_id,
        session_ref: "session-app-replay",
        operation: "registration",
        telephone_candidate_ref: telephone.public_id,
        normalized_number_digest: telephone.number_digest,
        now: @now,
      )
      result_token = Identity::TelephoneCeremony::ResultIssuer.issue!(
        grant_token: issuance.grant,
        candidate: telephone,
        surface: "app",
        actor_ref: user.public_id,
        session_ref: "session-app-replay",
        operation: "registration",
        now: @now,
      )

      assert_ceremony_error(/result session does not match current session/) do
        Identity::TelephoneCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: user,
          session_ref: "wrong-session",
          surface: "app",
          now: @now,
        )
      end
      assert_equal ClientTelephoneStatus::UNVERIFIED, telephone.reload.user_telephone_status_id

      Identity::TelephoneCeremony::FinalCommitter.call!(
        result_token: result_token,
        actor: user,
        session_ref: "session-app-replay",
        surface: "app",
        now: @now,
      )

      assert_ceremony_error(/transaction is already consumed/) do
        Identity::TelephoneCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: user,
          session_ref: "session-app-replay",
          surface: "app",
          now: @now,
        )
      end
    end
  end

  private

  def consumer
    Identity::TelephoneCeremony::ResultConsumer.new(transaction: @transaction, now: @now)
  end

  def valid_result_claims
    {
      "surface" => "app",
      "actor_ref" => "actor-client-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "normalized_number_digest" => "digest-1",
      "attempt_count" => 1,
      "expires_at" => 5.minutes.from_now.to_i,
    }
  end

  def valid_result_claims_for(transaction, result_jti:)
    valid_result_claims.merge(
      "surface" => transaction.surface,
      "actor_ref" => transaction.actor_ref,
      "session_ref" => transaction.session_ref,
      "transaction_id" => transaction.transaction_id,
      "grant_jti" => transaction.grant_jti,
      "operation" => transaction.operation,
      "result_jti" => result_jti,
    )
  end

  def create_app_transaction(identifier, expires_at:)
    create_transaction(ClientTelephoneCeremonyTransaction, identifier, surface: "app", expires_at: expires_at)
  end

  def create_transaction(model, identifier, surface:, expires_at:)
    model.create_transaction!(
      surface: surface,
      actor_ref: "actor-#{identifier}",
      session_ref: "session-#{identifier}",
      operation: "registration",
      transaction_id: "txn-#{identifier}",
      grant_jti: "grant-#{identifier}",
      normalized_number_digest: "digest-#{identifier}",
      now: @now,
      expires_at: expires_at,
    )
  end

  def issue_result_token(claims)
    Identity::TelephoneCeremony::Result.issue(
      claims,
      issuer_id: Identity::TelephoneCeremony::Contract.sign_issuer_id("app"),
      now: @now,
    )
  end

  def sign_result_payload(claims)
    payload = valid_result_claims.merge(
      "typ" => Identity::TelephoneCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::TelephoneCeremony::Contract.sign_issuer(claims.fetch("surface", "app")),
      "aud" => Identity::TelephoneCeremony::Contract.acme_audience(claims.fetch("surface", "app")),
      "purpose" => Identity::TelephoneCeremony::Result::PURPOSE,
      "proof_method" => Identity::TelephoneCeremony::Result::PROOF_METHOD,
      "iat" => @now.to_i,
      "exp" => claims.fetch("expires_at", valid_result_claims["expires_at"]),
    ).merge(claims)

    private_key = Jit::Security::Jwt::Keyring.private_key_for_active(
      Identity::TelephoneCeremony::Contract.sign_issuer_id("app"),
    )
    kid = Jit::Security::Jwt::Keyring.active_kid(Identity::TelephoneCeremony::Contract.sign_issuer_id("app"))
    JWT.encode(payload, private_key, "ES384", { "typ" => payload.fetch("typ"), "kid" => kid })
  end

  def assert_ceremony_error(pattern)
    error = assert_raises(Identity::TelephoneCeremony::Error) { yield }
    assert_match pattern, error.message
  end

  def assert_no_telephone_account_mutation
    before_counts = telephone_account_counts
    yield

    assert_equal before_counts, telephone_account_counts
  end

  def telephone_account_counts
    {
      client: ClientTelephone.count,
      operator: OperatorTelephone.count,
      visitor: VisitorTelephone.count,
    }
  end

  def tamper_payload(token, overrides)
    header_segment, payload_segment, signature_segment = token.split(".")
    payload = JSON.parse(Base64.urlsafe_decode64(pad_base64(payload_segment))).merge(overrides)
    encoded_payload = Base64.urlsafe_encode64(payload.to_json, padding: false)
    [header_segment, encoded_payload, signature_segment].join(".")
  end

  def pad_base64(value)
    padding = (4 - (value.length % 4)) % 4
    value + ("=" * padding)
  end
end
