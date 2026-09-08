# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"

class SecurityOneTimeRevealPurgeJobTest < ActiveJob::TestCase
  setup do
    SecurityOneTimeReveal.delete_all
  end

  # Boundary: a row whose expires_at is strictly in the past is deleted; one expiring exactly at
  # `now` or later is retained. `SecurityOneTimeReveal.consume` refuses on `expires_at <= now`, so
  # deleting on the same instant would only ever remove a row that is already refused -- but
  # deleting a row that is still inside its window would destroy a reveal its owner can still use.
  test "deletes only reveals whose window has already closed" do
    # Time is frozen because the job reads its own `Time.current`. Without this the boundary row
    # is a second in the past by the time the job runs, and the assertion below would pass or fail
    # on how slow the test was.
    freeze_time do
      now = Time.current

      expired = reveal(expires_at: now - 1.second)
      boundary = reveal(expires_at: now)
      active = reveal(expires_at: now + 5.minutes)

      SecurityOneTimeRevealPurgeJob.perform_now

      assert_not SecurityOneTimeReveal.exists?(expired.id)
      assert SecurityOneTimeReveal.exists?(boundary.id)
      assert SecurityOneTimeReveal.exists?(active.id)
    end
  end

  # The encrypted payload is the reason this job exists: a consumed reveal has been read, but the
  # ciphertext stays on the row until something deletes it.
  test "deletes a consumed reveal once it is expired" do
    consumed = reveal(expires_at: 1.minute.ago, consumed_at: 2.minutes.ago)

    SecurityOneTimeRevealPurgeJob.perform_now

    assert_not SecurityOneTimeReveal.exists?(consumed.id)
  end

  test "is a no-op when nothing is expired" do
    reveal(expires_at: 5.minutes.from_now)

    assert_no_difference -> { SecurityOneTimeReveal.count } do
      SecurityOneTimeRevealPurgeJob.perform_now
    end
  end

  test "purges more rows than one batch holds" do
    3.times { reveal(expires_at: 1.minute.ago) }

    assert_difference -> { SecurityOneTimeReveal.count }, -3 do
      SecurityOneTimeRevealPurgeJob.perform_now(batch_size: 1)
    end
  end

  # A purge job nobody schedules is the same as no purge job. Both environments that run recurring
  # work register the consumed-jti sweep; this one keys on the same column for the same reason and
  # has to sit beside it.
  test "the job is registered in every recurring schedule that sweeps expires_at tables" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))

    %w(development production).each do |environment|
      classes = recurring.fetch(environment).values.filter_map { |entry| entry["class"] }

      assert_includes classes, "SecurityOneTimeRevealPurgeJob", environment
      assert_includes classes, "SecurityConsumedJtiPurgeJob", environment
    end
  end

  private

  def reveal(expires_at:, consumed_at: nil)
    SecurityOneTimeReveal.create!(
      jti_digest: SecureRandom.hex(16),
      actor_type: "Client",
      actor_id: 1,
      session_nonce_digest: SecureRandom.hex(16),
      purpose: "client.recovery_secret_credential",
      encrypted_payload: "sealed-payload",
      expires_at: expires_at,
      consumed_at: consumed_at,
    )
  end
end
