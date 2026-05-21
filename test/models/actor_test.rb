# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorTest < ActiveSupport::TestCase
  setup { Actor.reset }
  teardown { Actor.reset }

  test "stores actor state in current attributes" do
    user = Client.new(id: 123)
    Actor.actor = user
    Actor.actor_type = :client

    assert_equal user, Actor.actor
    assert_equal :client, Actor.actor_type
    assert_equal user, Actor.client
    assert_predicate Actor, :client?
    assert_predicate Actor, :authenticated?
  end

  test "stores request context values in current attributes" do
    preference = Actor::Preference.new(language: "en", theme: "dr")
    Actor.account = "account-1"
    Actor.tenant = "tenant-1"
    Actor.tld = :app
    Actor.authentication = Actor::Authentication.new(
      login_public_id: "session-1",
      access_claims: { "sub" => "123" },
    )
    Actor.preference = preference
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    assert_equal "account-1", Actor.account
    assert_equal "tenant-1", Actor.tenant
    assert_equal :app, Actor.tld
    assert_equal "session-1", Actor.authentication.login_public_id
    assert_equal({ "sub" => "123" }, Actor.authentication.access_claims)
    assert_equal preference, Actor.preference
    assert_equal "trace-1", Actor.trace_id
    assert_equal "span-1", Actor.span_id
  end

  test "whoami aliases actor type" do
    Actor.actor_type = :visitor

    assert_equal :visitor, Actor.whoami
  end

  test "tld stores surface label" do
    Actor.tld = :dev

    assert_equal :dev, Actor.tld
  end

  test "context updates replace immutable snapshot" do
    original = Actor.context

    Actor.actor_type = :client

    assert_instance_of Actor::Context, original
    assert_instance_of Actor::Context, Actor.context
    assert_not_same original, Actor.context
    assert_equal :unauthenticated, original.actor_type
    assert_equal :client, Actor.context.actor_type
  end

  test "clear empties current actor context" do
    Actor.actor = Client.new(id: 123)
    Actor.actor_type = :client
    Actor.authentication = Actor::Authentication.new(
      login_public_id: "session-1",
      access_claims: { "sub" => "123" },
    )
    Actor.configuration = Actor::Configuration.new(foo: "bar")
    Actor.preference = Actor::Preference.new(language: "en")
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    Actor.clear

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authentication
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.trace_id
    assert_nil Actor.span_id
  end

  test "authentication access claims are recursively frozen" do
    Actor.authentication = Actor::Authentication.new(
      access_claims: { "scp" => ["read:self"], "prf" => { "lx" => "ja" } },
    )

    assert_predicate Actor.authentication.access_claims, :frozen?
    assert_predicate Actor.authentication.access_claims["scp"], :frozen?
    assert_predicate Actor.authentication.access_claims["prf"], :frozen?
  end
end
