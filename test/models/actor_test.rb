# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorTest < ActiveSupport::TestCase
  setup { Actor.reset }
  teardown { Actor.reset }

  test "stores actor state in current attributes" do
    user = User.new(id: 123)
    Actor.actor = user
    Actor.actor_type = :user

    assert_equal user, Actor.actor
    assert_equal :user, Actor.actor_type
    assert_equal user, Actor.user
    assert_predicate Actor, :user?
    assert_predicate Actor, :authenticated?
  end

  test "stores request context values in current attributes" do
    preference = Actor::Preference.new(language: "en", theme: "dr")
    Actor.account = "account-1"
    Actor.tenant = "tenant-1"
    Actor.surface = :app
    Actor.session = "session-1"
    Actor.token = { "sub" => "123" }
    Actor.preference = preference
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    assert_equal "account-1", Actor.account
    assert_equal "tenant-1", Actor.tenant
    assert_equal :app, Actor.surface
    assert_equal :app, Actor.domain
    assert_equal "session-1", Actor.session
    assert_equal({ "sub" => "123" }, Actor.token)
    assert_equal preference, Actor.preference
    assert_equal "trace-1", Actor.trace_id
    assert_equal "span-1", Actor.span_id
  end

  test "surface falls back to legacy domain during migration" do
    Actor.domain = :org

    assert_equal :org, Actor.surface
  end
end
