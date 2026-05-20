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
end
