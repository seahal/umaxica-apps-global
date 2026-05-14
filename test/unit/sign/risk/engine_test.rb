# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Risk
    class EngineTest < ActiveSupport::TestCase
      setup do
        UserOccurrenceStatus.find_or_create_by!(id: UserOccurrenceStatus::ACTIVE)
        VisitorOccurrenceStatus.ensure_defaults!
        @user = User.create!(status_id: UserStatus::NOTHING, public_id: "risk_#{SecureRandom.hex(6)}")
      end

      test "refresh_reuse_detected returns 100" do
        # We need to inject events into the Engine's view.
        # Since Engine reads from Redis, we should populate Redis (or our mock).

        # Ideally, we stub `Sign::Risk::Engine#score` to use our mock,
        # BUT the code uses `cat` `REDIS_CLIENT`.

        # Let's try to trust that we can simply create events and persist them if REDIS_CLIENT is available.
        # If REDIS_CLIENT isn't available in test env, our code returns 0.
        # The prompt implies we should implement it.

        # Let's see if we can use Minitest::Mock on REDIS_CLIENT if it exists?
        # Or define it if missing.

        Emitter.send(:persist, Event.new("refresh_reuse_detected", payload: { user_id: @user.id }))

        assert_equal 100, Engine.score(user_id: @user.id)
      end

      test "auth_failed 5 times returns 60" do
        5.times do
          Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id }))
        end

        assert_equal 60, Engine.score(user_id: @user.id)
      end

      test "refresh_failed 5 times returns 40" do
        5.times do
          Emitter.send(:persist, Event.new("refresh_failed", payload: { user_id: @user.id }))
        end

        assert_equal 40, Engine.score(user_id: @user.id)
      end

      test "mixed events return max score" do
        Emitter.send(:persist, Event.new("refresh_reuse_detected", payload: { user_id: @user.id }))
        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 100, Engine.score(user_id: @user.id)
      end

      test "returns 0 for safe events" do
        Emitter.send(:persist, Event.new("session_issued", payload: { user_id: @user.id }))

        assert_equal 0, Engine.score(user_id: @user.id)
      end

      test "visitor auth_failed 5 times returns 60" do
        5.times do
          Emitter.send(:persist, Event.new("auth_failed", payload: { visitor_id: 123 }))
        end

        assert_equal 60, Engine.score(visitor_id: 123)
      end
    end
  end
end
