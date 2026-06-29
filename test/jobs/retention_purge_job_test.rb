# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RetentionPurgeJobTest < ActiveJob::TestCase
  test "anonymizes account records where purged_at is in the past" do
    user_to_purge = Client.create!(public_id: "purge_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    user_to_keep = Client.create!(public_id: "keep_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)

    user_to_purge.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)
    user_to_keep.update_columns(discarded_at: Retainable::SENTINEL, purged_at: Retainable::SENTINEL)

    assert_no_difference -> { Client.count } do
      RetentionPurgeJob.perform_now
    end

    assert_predicate user_to_purge.reload, :terminated?
    assert Client.exists?(user_to_keep.id)
    assert_nil user_to_keep.reload.terminated_at
  end

  # Staff (Operator) lifecycle and User (Client) withdrawal must NOT be
  # conflated by the purge worker. Clients are anonymized *in place*
  # (`terminated_at` set, row retained for referential history), while Operators
  # are *physically removed* via the set-based `purge_operators` path (no
  # `terminated_at` marker -- Staff has no withdrawal lifecycle). A regression
  # that routed Operators through `anonymize_accounts` (or Clients through
  # `purge_operators`) would silently corrupt one actor type's lifecycle.
  test "purge physically removes due operators but anonymizes due users in place" do
    user = Client.create!(public_id: "puser_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator_due = Operator.create!
    operator_pending = Operator.create!

    user.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)
    operator_due.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)
    operator_pending.update_columns(discarded_at: Retainable::SENTINEL, purged_at: Retainable::SENTINEL)

    assert_difference -> { Operator.count }, -1 do
      assert_no_difference -> { Client.count } do
        RetentionPurgeJob.perform_now
      end
    end

    # User: retained but anonymized/terminated (User withdrawal lifecycle).
    assert Client.exists?(user.id)
    assert_predicate user.reload, :terminated?

    # Operator: physically deleted, never marked terminated (Staff lifecycle).
    assert_not Operator.exists?(operator_due.id)

    # Operator not yet due (purged_at = Infinity sentinel) must be untouched.
    assert Operator.exists?(operator_pending.id)
  end

  # Re-running the worker must be safe: already-anonymized users are skipped via
  # `where(terminated_at: nil)` and already-deleted operators are simply absent.
  test "purge is idempotent across repeated runs" do
    user = Client.create!(public_id: "iuser_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator = Operator.create!
    user.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)
    operator.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)

    RetentionPurgeJob.perform_now
    terminated_at_after_first = user.reload.terminated_at

    assert_nothing_raised { RetentionPurgeJob.perform_now }

    assert Client.exists?(user.id)
    assert_predicate user.reload, :terminated?
    assert_equal terminated_at_after_first, user.reload.terminated_at,
                 "terminated_at must not be rewritten on subsequent runs"
    assert_not Operator.exists?(operator.id)
  end

  test "purges visitor occurrences where purged_at is in the past" do
    VisitorOccurrenceStatus.ensure_defaults!
    occurrence_to_purge = VisitorOccurrence.create!(body: "purge-#{SecureRandom.hex(8)}")
    occurrence_to_keep = VisitorOccurrence.create!(body: "keep-#{SecureRandom.hex(8)}")

    occurrence_to_purge.update_columns(discarded_at: 1.hour.ago, purged_at: 1.hour.ago)
    occurrence_to_keep.update_columns(discarded_at: Retainable::SENTINEL, purged_at: Retainable::SENTINEL)

    assert_difference -> { VisitorOccurrence.count }, -1 do
      RetentionPurgeJob.perform_now
    end

    assert_not VisitorOccurrence.exists?(occurrence_to_purge.id)
    assert VisitorOccurrence.exists?(occurrence_to_keep.id)
  end

  test "runs sign up artifact cleanup before purging signup cycles" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: user,
      raw_address: "retention-cleanup-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = ClientSignUpFlow.create!(
      principal_id: user.id,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: 20.minutes.ago,
      expires_at: 5.minutes.ago,
      entry_method: "email",
      pending_contact_type: "email",
      pending_contact_id: email.id,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )
    cycle.update_columns(discarded_at: cycle.created_at, purged_at: cycle.created_at)

    RetentionPurgeJob.perform_now

    assert_not ClientSignUpFlow.exists?(cycle.id)
    assert_equal ClientEmailStatus::DELETED, email.reload.user_email_status_id
    assert_operator email.discarded_at, :<=, Time.current
  end

  # Regression guard for RETAINABLE_MODELS ordering. ClientSignUpFlow has an
  # ON DELETE CASCADE FK to ClientToken; if RETAINABLE_MODELS lists ClientToken
  # before ClientSignUpFlow, purging tokens will silently cascade-delete
  # active cycles whose own `purged_at` is still Infinity.
  test "ClientSignUpFlow is listed before ClientToken in RETAINABLE_MODELS" do
    models = RetentionPurgeJob::RETAINABLE_MODELS
    cycle_index = models.index(ClientSignUpFlow)
    token_index = models.index(ClientToken)

    assert cycle_index, "ClientSignUpFlow missing from RETAINABLE_MODELS"
    assert token_index, "ClientToken missing from RETAINABLE_MODELS"
    assert_operator cycle_index, :<, token_index,
                    "ClientSignUpFlow must precede ClientToken to avoid cascade-deletion of active cycles"
  end

  test "VisitorSignUpFlow is listed before VisitorToken in RETAINABLE_MODELS" do
    models = RetentionPurgeJob::RETAINABLE_MODELS
    cycle_index = models.index(VisitorSignUpFlow)
    token_index = models.index(VisitorToken)

    assert cycle_index, "VisitorSignUpFlow missing from RETAINABLE_MODELS"
    assert token_index, "VisitorToken missing from RETAINABLE_MODELS"
    assert_operator cycle_index, :<, token_index,
                    "VisitorSignUpFlow must precede VisitorToken"
  end

  # Every Retainable model must be registered with RetentionPurgeJob so the
  # worker actually purges its rows. Forgetting to add a new model is silent --
  # `purged_at` ticks past forever with no one cleaning up. Compare against
  # the Retainable.registry that models populate on `included`.
  test "all Retainable-including models are registered in RETAINABLE_MODELS" do
    # Force eager load so every Retainable include block runs and registers.
    Rails.application.eager_load!

    missing =
      (Retainable.registry - RetentionPurgeJob::RETAINABLE_MODELS).reject do |model|
        model.name.to_s.match?(/\A(?:CycleBaseTest|RetainableTest|SecretCredentialConcernTest)::/) ||
          !model.table_exists?
      end

    assert_empty missing,
                 "Models include Retainable but are absent from RetentionPurgeJob::RETAINABLE_MODELS -- " \
                 "rows in these tables will never be physically purged: #{missing.map(&:name).sort.join(", ")}"
  end
end
