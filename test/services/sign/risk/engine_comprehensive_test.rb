# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Risk
    class EngineComprehensiveTest < ActiveSupport::TestCase
      fixtures :clients

      setup do
        ClientOccurrenceStatus.find_or_create_by!(id: ClientOccurrenceStatus::ACTIVE)
        VisitorOccurrenceStatus.ensure_defaults!
        @user = clients(:one)

        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
        @original_disabled = original_disabled
        @original_enabled = original_enabled
      end

      teardown do
        ENV["RISK_ENFORCEMENT_DISABLED"] = @original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = @original_enabled
      end

      test "score returns 0 when no user_id or staff_id provided" do
        assert_equal 0, Engine.score
      end

      test "score returns 0 for user with no events" do
        assert_equal 0, Engine.score(user_id: @user.id)
      end

      test "score returns 100 for refresh_reuse_detected" do
        Emitter.send(:persist, Event.new("refresh_reuse_detected", payload: { user_id: @user.id }))

        assert_equal 100, Engine.score(user_id: @user.id)
      end

      test "score returns 60 for 5 auth_failed events" do
        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 60, Engine.score(user_id: @user.id)
      end

      test "score returns 0 for fewer than 5 auth_failed" do
        4.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 0, Engine.score(user_id: @user.id)
      end

      test "score returns 40 for 5 refresh_failed events" do
        5.times { Emitter.send(:persist, Event.new("refresh_failed", payload: { user_id: @user.id })) }

        assert_equal 40, Engine.score(user_id: @user.id)
      end

      test "score returns 0 for fewer than 5 refresh_failed" do
        4.times { Emitter.send(:persist, Event.new("refresh_failed", payload: { user_id: @user.id })) }

        assert_equal 0, Engine.score(user_id: @user.id)
      end

      test "refresh_reuse_detected takes priority over auth_failed" do
        Emitter.send(:persist, Event.new("refresh_reuse_detected", payload: { user_id: @user.id }))
        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 100, Engine.score(user_id: @user.id)
      end

      test "auth_failed takes priority over refresh_failed" do
        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }
        5.times { Emitter.send(:persist, Event.new("refresh_failed", payload: { user_id: @user.id })) }

        assert_equal 60, Engine.score(user_id: @user.id)
      end

      test "score is scoped to specific user" do
        other_user = Client.create!(
          status_id: ClientStatus::NOTHING,
          public_id: "engine_#{SecureRandom.hex(4)}".upcase.first(16),
        )

        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 60, Engine.score(user_id: @user.id)
        assert_equal 0, Engine.score(user_id: other_user.id)
      end

      test "score is scoped to specific visitor" do
        5.times { Emitter.send(:persist, Event.new("auth_failed", payload: { visitor_id: 123 })) }

        assert_equal 60, Engine.score(visitor_id: 123)
        assert_equal 0, Engine.score(visitor_id: 456)
      end

      test "safe events return 0" do
        Emitter.send(:persist, Event.new("session_issued", payload: { user_id: @user.id }))

        assert_equal 0, Engine.score(user_id: @user.id)
      end
    end
  end
end
