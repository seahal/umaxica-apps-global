# typed: false
# frozen_string_literal: true

require "test_helper"

module SignUp
  class CycleLocatorTest < ActiveSupport::TestCase
    test "issue stores a session locator and current resolves the cycle" do
      session = {}
      cycle = create_cycle(nonce: "old-nonce")
      locator = CycleLocator.new(session, surface: :app)

      locator.issue!(cycle, nonce: "fresh-nonce")

      assert_equal cycle.public_id, session.dig(:app_sign_up_cycle_locator, "public_id")
      assert_equal "fresh-nonce", session.dig(:app_sign_up_cycle_locator, "nonce")
      assert_equal cycle, locator.current
      assert cycle.reload.nonce_matches?("fresh-nonce")
      assert_not cycle.nonce_matches?("old-nonce")
    end

    test "bad nonce rejects without mutating cycle state" do
      session = {}
      cycle = create_cycle(nonce: "correct-nonce")
      locator = CycleLocator.new(session, surface: :app)
      locator.issue!(cycle, nonce: "correct-nonce")

      session[:app_sign_up_cycle_locator]["nonce"] = "bad-nonce"

      assert_nil locator.current
      assert_equal ClientSignUpCycleStatus::STARTED, cycle.reload.status_id
    end

    test "expired and terminal cycles reject" do
      session = {}
      expired = create_cycle(nonce: "expired", issued_at: 2.minutes.ago, expires_at: 1.minute.ago)
      locator = CycleLocator.new(session, surface: :app)
      locator.issue!(expired, nonce: "expired")

      assert_nil locator.current

      completed = create_cycle(
        nonce: "completed",
        status_id: ClientSignUpCycleStatus::COMPLETED,
        step: "completed",
        completed_at: Time.current,
      )
      locator.issue!(completed, nonce: "completed")

      assert_nil locator.current
    end

    test "surface-specific locator does not read another surface key" do
      session = {}
      cycle = create_cycle(nonce: "nonce")
      CycleLocator.new(session, surface: :app).issue!(cycle, nonce: "nonce")

      assert_nil CycleLocator.new(session, surface: :com).current
    end

    private

    def create_cycle(nonce:, **overrides)
      ClientSignUpCycle.create!(
        {
          principal_id: nil,
          status_id: ClientSignUpCycleStatus::STARTED,
          step: "start",
          nonce_digest: ClientSignUpCycle.digest_nonce(nonce),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
          entry_method: "telephone",
        }.merge(overrides),
      )
    end
  end
end
