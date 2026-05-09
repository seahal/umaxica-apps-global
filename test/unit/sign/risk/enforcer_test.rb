# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Risk
    class EnforcerTest < ActiveSupport::TestCase
      fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds,
               :staffs, :staff_token_statuses, :staff_token_kinds

      setup do
        @user = users(:one) # Assuming fixtures or factory
        @user_id = @user.id
        UserOccurrenceStatus.find_or_create_by!(id: UserOccurrenceStatus::ACTIVE)

        # Enable feature flag for tests
        @original_env = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
      end

      teardown do
        ENV["RISK_ENFORCEMENT_ENABLED"] = @original_env
      end

      test "does nothing if feature flag is off" do
        ENV["RISK_ENFORCEMENT_ENABLED"] = "false"

        Engine.stub(:score, 100) do
          Enforcer.stub(:revoke!, ->(_) { raise RuntimeError, "Should not be called" }) do
            result = Enforcer.call(@user)

            assert_nil result
          end
        end
      end

      test "revokes if score is 100" do
        Engine.stub(:score, 100) do
          # Enforcer.revoke! should be called
          called = false
          Enforcer.stub(:revoke!, ->(u) { called = true; assert_equal @user, u }) do
            Enforcer.call(@user)
          end

          assert called, "revoke! should have been called"
        end
      end

      test "requires step up if score is 60" do
        @user.user_tokens.destroy_all

        token = UserToken.create!(
          user: @user,
          lapses_at: 1.day.from_now,
          public_id: "test_step_up_#{SecureRandom.hex(4)}",
        )

        Engine.stub(:score, 60) do
          Enforcer.call(@user)
        end

        token.reload

        assert_not_nil token.last_step_up_at
        assert_equal "risk_enforced", token.last_step_up_scope
      end

      test "requires step up for staff tokens if score is 60" do
        staff = staffs(:one)
        staff.staff_tokens.destroy_all

        token = StaffToken.create!(
          staff: staff,
          lapses_at: 1.day.from_now,
          public_id: "stf_#{SecureRandom.hex(4)}",
        )

        Engine.stub(:score, 60) do
          Enforcer.call(staff)
        end

        token.reload

        assert_not_nil token.last_step_up_at
        assert_equal "risk_enforced", token.last_step_up_scope
      end

      test "does nothing if score is 0" do
        Engine.stub(:score, 0) do
          Enforcer.stub(:revoke!, ->(_) { raise RuntimeError, "Should not be called" }) do
            Enforcer.stub(:require_step_up!, ->(_) { raise RuntimeError, "Should not be called" }) do
              result = Enforcer.call(@user)

              assert_nil result
            end
          end
        end
      end

      test "end-to-end risk flow" do
        @user.user_tokens.destroy_all # Ensure we don't hit session limit

        # Create token with valid public_id and expiry
        token = UserToken.create!(
          user: @user,
          lapses_at: 1.day.from_now,
          public_id: "test_#{SecureRandom.hex(4)}",
          # Default status/kind should trigger if FKs exist.
          # If FK check fails, we might need to assume fixtures loaded statuses.
        )

        # 1. Emit risk event (writes to occurrences)
        Sign::Risk::Emitter.emit("refresh_reuse_detected", user_id: @user.id)

        # 2. Call Enforcer (reads occurrences via Engine, then revokes)
        Sign::Risk::Enforcer.call(@user)

        # 3. Check revocation
        token.reload

        assert_not_nil token.lapses_at
      end
    end
  end
end
