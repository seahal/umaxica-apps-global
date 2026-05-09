# typed: false
# frozen_string_literal: true

require "test_helper"

class RetentionPurgeJobTest < ActiveJob::TestCase
  test "purges records where purge_at is in the past" do
    # Assuming User is one of the models
    user_to_purge = User.create!(public_id: "purge_#{SecureRandom.uuid}".chars.first(16).join, status_id: UserStatus::ACTIVE)
    user_to_keep = User.create!(public_id: "keep_#{SecureRandom.uuid}".chars.first(16).join, status_id: UserStatus::ACTIVE)

    # We bypass validations by using update_columns
    user_to_purge.update_columns(lapses_at: 1.hour.ago, purge_at: 1.hour.ago)
    user_to_keep.update_columns(lapses_at: Retainable::SENTINEL, purge_at: Retainable::SENTINEL)

    assert_difference -> { User.count }, -1 do
      RetentionPurgeJob.perform_now
    end

    assert_not User.exists?(user_to_purge.id)
    assert User.exists?(user_to_keep.id)
  end
end
