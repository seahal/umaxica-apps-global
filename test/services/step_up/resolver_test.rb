# typed: false
# frozen_string_literal: true

require "test_helper"

module StepUp
  class ResolverTest < ActiveSupport::TestCase
    Token =
      Struct.new(:currently_usable, :last_step_up_at, :last_step_up_scope, keyword_init: true) do
        def currently_usable? = currently_usable
      end

    test "returns satisfied when token is usable, fresh, and scope matches" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = Token.new(currently_usable: true, last_step_up_at: now - 5.minutes, last_step_up_scope: "profile")

      step_up = Resolver.call(token: token, scope: "profile", now: now)

      assert_predicate step_up, :satisfied?
      assert_predicate step_up, :usable_token?
      assert_equal "profile", step_up.scope
      assert_equal :aal2, step_up.required_aal
      assert_equal now + 10.minutes, step_up.expires_at
    end

    test "returns unsatisfied when token is expired, unusable, or scope mismatched" do
      now = Time.zone.parse("2026-05-25 00:00:00")

      expired = Token.new(currently_usable: true, last_step_up_at: now - 16.minutes, last_step_up_scope: "profile")
      unusable = Token.new(currently_usable: false, last_step_up_at: now - 5.minutes, last_step_up_scope: "profile")
      mismatched = Token.new(currently_usable: true, last_step_up_at: now - 5.minutes, last_step_up_scope: "other")

      assert_not Resolver.call(token: expired, scope: "profile", now: now).satisfied?
      assert_not Resolver.call(token: unusable, scope: "profile", now: now).satisfied?
      assert_not Resolver.call(token: mismatched, scope: "profile", now: now).satisfied?
    end
  end
end
