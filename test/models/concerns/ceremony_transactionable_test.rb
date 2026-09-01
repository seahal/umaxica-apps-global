# typed: false
# frozen_string_literal: true

require "test_helper"

class CeremonyTransactionableTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  TRANSACTION_CLASSES = [
    ClientTelephoneCeremonyTransaction,
    ClientSecretCredentialCeremonyTransaction,
    ClientTotpCeremonyTransaction,
    ClientPasskeyCeremonyTransaction,
    ClientEmailCeremonyTransaction,
  ].freeze

  CEREMONY_ERRORS = [
    IdentityTelephoneCeremony::Error,
    IdentitySecretCredentialCeremonyContract::Error,
    IdentityTotpCeremonyContract::Error,
    IdentityPasskeyCeremonyContract::Error,
    IdentityEmailCeremonyContract::Error,
  ].freeze

  CEREMONY_OPERATIONS = %w(registration enrollment registration registration registration).freeze

  setup do
    @now = Time.zone.parse("2026-07-15 12:00:00")
  end

  teardown do
    travel_back
  end

  test "transaction classes create pending records with claims and expiry behavior" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        transaction = transaction_class.create_transaction!(
          actor_ref: "actor-#{index}",
          session_ref: "session-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          now: @now,
        )

        assert_equal "app", transaction.surface
        assert_equal "pending", transaction.status
        assert_equal CEREMONY_OPERATIONS[index], transaction.operation
        assert_equal @now + 10.minutes, transaction.expires_at
        assert_not transaction.expired?(now: @now)
        assert transaction.expired?(now: transaction.expires_at)
        assert_not transaction.consumed?
        assert_equal "actor-#{index}", transaction.grant_claims.fetch("actor_ref")
        assert_equal "session-#{index}", transaction.grant_claims.fetch("session_ref")
        assert_predicate transaction.transaction_id, :present?
        assert_predicate transaction.grant_jti, :present?
        assert_equal transaction.grant_jti, transaction.grant_claims.fetch("jti")
        assert_equal transaction.transaction_id, transaction.grant_claims.fetch("transaction_id")
      end
    end
  end

  test "transaction classes consume a pending record exactly once" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        transaction = transaction_class.create_transaction!(
          actor_ref: "actor-consume-#{index}",
          session_ref: "session-consume-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-consume-#{index}",
          grant_jti: "grant-consume-#{index}",
          now: @now,
        )

        consumed = transaction.consume_result!(
          result_jti: "result-#{index}",
          consumed_at: @now,
        )

        assert_predicate consumed, :consumed?
        assert_equal "result-#{index}", consumed.result_jti
        assert_equal @now, consumed.consumed_at

        error =
          assert_raises(CEREMONY_ERRORS[index]) do
            consumed.consume_result!(result_jti: "result-again-#{index}", consumed_at: @now)
          end
        assert_match(/already consumed/, error.message)
      end
    end
  end

  test "transaction classes reject mismatched and incomplete consumed records" do
    TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
      mismatched = transaction_class.new(
        surface: "com",
        actor_ref: "actor-invalid-#{index}",
        session_ref: "session-invalid-#{index}",
        operation: CEREMONY_OPERATIONS[index],
        status: "pending",
        transaction_id: "transaction-invalid-#{index}",
        grant_jti: "grant-invalid-#{index}",
        expires_at: 10.minutes.from_now,
      )

      assert_not mismatched.valid?
      assert_includes mismatched.errors.attribute_names, :surface

      consumed_without_result = transaction_class.new(
        surface: "app",
        actor_ref: "actor-consumed-#{index}",
        session_ref: "session-consumed-#{index}",
        operation: CEREMONY_OPERATIONS[index],
        status: "consumed",
        transaction_id: "transaction-consumed-#{index}",
        grant_jti: "grant-consumed-#{index}",
        expires_at: 10.minutes.from_now,
      )

      assert_not consumed_without_result.valid?
      assert_includes consumed_without_result.errors.attribute_names, :result_jti
    end
  end

  test "transaction classes expose scopes and preserve optional claims" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        options = {
          actor_ref: "actor-scope-#{index}",
          session_ref: "session-scope-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-scope-#{index}",
          grant_jti: "grant-scope-#{index}",
          expires_at: @now + 1.hour,
          now: @now,
        }
        options[:telephone_candidate_ref] =
          "telephone-candidate-#{index}" if transaction_class.column_names.include?("telephone_candidate_ref")
        options[:normalized_number_digest] =
          "number-digest-#{index}" if transaction_class.column_names.include?("normalized_number_digest")
        options[:credential_candidate_ref] =
          "credential-candidate-#{index}" if transaction_class.column_names.include?("credential_candidate_ref")
        options[:credential_candidate_digest] =
          "credential-digest-#{index}" if transaction_class.column_names.include?("credential_candidate_digest")
        options[:email_candidate_ref] =
          "email-candidate-#{index}" if transaction_class.column_names.include?("email_candidate_ref")
        options[:normalized_email_digest] =
          "email-digest-#{index}" if transaction_class.column_names.include?("normalized_email_digest")
        if transaction_class.column_names.include?("evp_nonce_digest")
          options[:evp_nonce_digest] = "evp-nonce-#{index}"
          options[:evp_outcome] = "pending"
        end

        transaction = transaction_class.create_transaction!(**options)

        assert_includes transaction_class.pending, transaction
        assert_includes transaction_class.active_at(@now), transaction
        assert_includes transaction_class.expired_at(@now + 2.hours), transaction
        assert_includes transaction_class.purgeable_at(@now + 8.days), transaction
        assert_not_includes transaction_class.consumed, transaction
        assert_equal "telephone-candidate-#{index}",
                     transaction.grant_claims["telephone_candidate_ref"] \
                       if transaction.respond_to?(:telephone_candidate_ref)
        assert_equal "credential-candidate-#{index}",
                     transaction.grant_claims["credential_candidate_ref"] \
                       if transaction.respond_to?(:credential_candidate_ref)
        assert_equal "email-candidate-#{index}",
                     transaction.grant_claims["email_candidate_ref"] if transaction.respond_to?(:email_candidate_ref)
        assert_equal "pending", transaction.evp_outcome if transaction.respond_to?(:evp_outcome)
      end
    end
  end

  test "transaction classes reject consuming expired and duplicate result records" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        expired = transaction_class.create_transaction!(
          actor_ref: "actor-expired-#{index}",
          session_ref: "session-expired-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-expired-#{index}",
          grant_jti: "grant-expired-#{index}",
          expires_at: @now - 1.minute,
          now: @now,
        )

        assert_raises(CEREMONY_ERRORS[index]) do
          expired.consume_result!(result_jti: "result-expired-#{index}", consumed_at: @now)
        end

        first = transaction_class.create_transaction!(
          actor_ref: "actor-duplicate-#{index}",
          session_ref: "session-duplicate-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-first-#{index}",
          grant_jti: "grant-first-#{index}",
          now: @now,
        )
        second = transaction_class.create_transaction!(
          actor_ref: "actor-duplicate-#{index}",
          session_ref: "session-duplicate-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-second-#{index}",
          grant_jti: "grant-second-#{index}",
          now: @now,
        )

        first.consume_result!(result_jti: "result-duplicate-#{index}", consumed_at: @now)

        assert_raises(CEREMONY_ERRORS[index]) do
          second.consume_result!(result_jti: "result-duplicate-#{index}", consumed_at: @now)
        end
      end
    end
  end

  test "transaction classes select the correct writing connection owner" do
    assert_equal AppTicketRecord, ClientTelephoneCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorTelephoneCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorTelephoneCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientSecretCredentialCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorSecretCredentialCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorSecretCredentialCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientTotpCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientPasskeyCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorPasskeyCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorPasskeyCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientEmailCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorEmailCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorEmailCeremonyTransaction.connection_owner

    [
      TelephoneCeremonyTransactionable,
      SecretCredentialCeremonyTransactionable,
      TotpCeremonyTransactionable,
      PasskeyCeremonyTransactionable,
      EmailCeremonyTransactionable,
    ].each do |transactionable|
      generic_transaction_class =
        Class.new(ApplicationRecord) do
          include transactionable
        end

      assert_equal ActiveRecord::Base, generic_transaction_class.connection_owner
    end
  end
end
