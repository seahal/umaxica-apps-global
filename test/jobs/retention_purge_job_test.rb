# typed: false
# frozen_string_literal: true

require "test_helper"

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
    cycle = ClientSignUpCycle.create!(
      principal_id: user.id,
      status_id: ClientSignUpCycleStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: ClientSignUpCycle.digest_nonce("nonce"),
      issued_at: 20.minutes.ago,
      expires_at: 5.minutes.ago,
      entry_method: "email",
      pending_contact_type: "email",
      pending_contact_id: email.id,
      cleanup_status_id: ClientSignUpCycleCleanupStatus::PENDING,
      discarded_at: 1.hour.ago,
      purged_at: 1.hour.ago,
    )

    RetentionPurgeJob.perform_now

    assert_not ClientSignUpCycle.exists?(cycle.id)
    assert_equal ClientEmailStatus::DELETED, email.reload.user_email_status_id
    assert_operator email.discarded_at, :<=, Time.current
  end

  # Regression guard for RETAINABLE_MODELS ordering. ClientSignUpCycle has an
  # ON DELETE CASCADE FK to ClientToken; if RETAINABLE_MODELS lists ClientToken
  # before ClientSignUpCycle, purging tokens will silently cascade-delete
  # active cycles whose own `purged_at` is still Infinity.
  test "ClientSignUpCycle is listed before ClientToken in RETAINABLE_MODELS" do
    models = RetentionPurgeJob::RETAINABLE_MODELS
    cycle_index = models.index(ClientSignUpCycle)
    token_index = models.index(ClientToken)

    skip "ClientToken not registered" unless token_index

    assert cycle_index, "ClientSignUpCycle missing from RETAINABLE_MODELS"
    assert_operator cycle_index, :<, token_index,
                    "ClientSignUpCycle must precede ClientToken to avoid cascade-deletion of active cycles"
  end

  test "VisitorSignUpCycle is listed before VisitorToken in RETAINABLE_MODELS" do
    models = RetentionPurgeJob::RETAINABLE_MODELS
    cycle_index = models.index(VisitorSignUpCycle)
    token_index = models.index(VisitorToken)

    skip "VisitorToken not registered" unless token_index

    assert cycle_index, "VisitorSignUpCycle missing from RETAINABLE_MODELS"
    assert_operator cycle_index, :<, token_index,
                    "VisitorSignUpCycle must precede VisitorToken"
  end

  # Every Retainable model must be registered with RetentionPurgeJob so the
  # worker actually purges its rows. Forgetting to add a new model is silent —
  # `purged_at` ticks past forever with no one cleaning up. Compare against
  # the Retainable.registry that models populate on `included`.
  test "all Retainable-including models are registered in RETAINABLE_MODELS" do
    # Force eager load so every Retainable include block runs and registers.
    Rails.application.eager_load!

    missing = Retainable.registry - RetentionPurgeJob::RETAINABLE_MODELS

    assert_empty missing,
                 "Models include Retainable but are absent from RetentionPurgeJob::RETAINABLE_MODELS — " \
                 "rows in these tables will never be physically purged: #{missing.map(&:name).sort.join(", ")}"
  end
end
