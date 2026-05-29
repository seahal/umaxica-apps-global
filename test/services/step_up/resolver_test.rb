# typed: false
# frozen_string_literal: true

require "test_helper"

module StepUp
  class ResolverTest < ActiveSupport::TestCase
    Token =
      Struct.new(
        :currently_usable,
        :public_id,
        :last_step_up_at,
        :last_step_up_scope,
        :last_step_up_aal,
        :last_step_up_method,
        :last_step_up_session_public_id,
        :last_step_up_purpose,
        :last_step_up_audience,
        keyword_init: true,
      ) do
        def currently_usable? = currently_usable

        def has_attribute?(attribute)
          members.include?(attribute.to_sym)
        end
      end

    test "returns satisfied when token is usable, fresh, and scope matches" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = Token.new(
        currently_usable: true,
        public_id: "token_1",
        last_step_up_at: now - 5.minutes,
        last_step_up_scope: "profile",
        last_step_up_aal: "aal2",
        last_step_up_method: "totp",
        last_step_up_session_public_id: "session_1",
      )

      step_up = Resolver.call(
        token: token,
        scope: "profile",
        session_binding: "session_1",
        token_binding: "token_1",
        now: now,
      )

      assert_predicate step_up, :satisfied?
      assert_predicate step_up, :usable_token?
      assert_equal "profile", step_up.scope
      assert_equal :aal2, step_up.required_aal
      assert_equal now + 10.minutes, step_up.expires_at
    end

    test "returns unsatisfied when token is expired, unusable, or scope mismatched" do
      now = Time.zone.parse("2026-05-25 00:00:00")

      expired = token_at(now - 16.minutes, scope: "profile")
      unusable = token_at(now - 5.minutes, currently_usable: false, scope: "profile")
      mismatched = token_at(now - 5.minutes, scope: "other")

      assert_not Resolver.call(token: expired, scope: "profile", now: now).satisfied?
      assert_not Resolver.call(token: unusable, scope: "profile", now: now).satisfied?
      assert_not Resolver.call(token: mismatched, scope: "profile", now: now).satisfied?
    end

    test "satisfies just before ttl and rejects exactly at ttl" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      ttl = 15.minutes

      just_before = token_at(now - ttl + 1.second, scope: "profile")
      exactly_at = token_at(now - ttl, scope: "profile")

      assert_predicate Resolver.call(token: just_before, scope: "profile", now: now, ttl: ttl), :satisfied?
      assert_not Resolver.call(token: exactly_at, scope: "profile", now: now, ttl: ttl).satisfied?
    end

    test "blank requested scope is never satisfied" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "configuration_email")

      assert_not Resolver.call(token: token, scope: nil, now: now).satisfied?
      assert_not Resolver.call(token: token, scope: "", now: now).satisfied?
      assert_not Resolver.call(token: token, scope: "configuration_passkey", now: now).satisfied?
    end

    test "rejects wrong method, unsupported aal, and binding mismatch" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "configuration_passkey", method: "email_otp")

      assert_not Resolver.call(token: token, scope: "configuration_passkey", now: now).satisfied?
      assert_not Resolver.call(token: token, scope: "configuration_passkey", required_aal: :aal3, now: now).satisfied?
      assert_not Resolver.call(
        token: token_at(now - 1.minute, scope: "configuration_passkey"),
        scope: "configuration_passkey",
        session_binding: "other_session",
        token_binding: "token_1",
        now: now,
      ).satisfied?
    end

    test "rejects wrong purpose and audience when requirement binds them" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(
        now - 1.minute,
        scope: "configuration_email",
        purpose: "step_up",
        audience: "step_up:app",
      )
      requirement = Requirement.new(
        scope: "configuration_email",
        purpose: "step_up",
        audience: "step_up:app",
      )

      assert_predicate Resolver.call(token: token, requirement: requirement, now: now), :satisfied?

      wrong_purpose = Requirement.new(
        scope: "configuration_email",
        purpose: "other",
        audience: "step_up:app",
      )
      wrong_audience = Requirement.new(
        scope: "configuration_email",
        purpose: "step_up",
        audience: "step_up:org",
      )

      assert_not Resolver.call(token: token, requirement: wrong_purpose, now: now).satisfied?
      assert_not Resolver.call(token: token, requirement: wrong_audience, now: now).satisfied?
    end

    private

    def token_at(time, currently_usable: true, scope:, aal: "aal2", method: "totp",
                 public_id: "token_1", session_public_id: "session_1",
                 purpose: nil, audience: nil)
      Token.new(
        currently_usable: currently_usable,
        public_id: public_id,
        last_step_up_at: time,
        last_step_up_scope: scope,
        last_step_up_aal: aal,
        last_step_up_method: method,
        last_step_up_session_public_id: session_public_id,
        last_step_up_purpose: purpose,
        last_step_up_audience: audience,
      )
    end
  end
end
