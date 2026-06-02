# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorTest < ActiveSupport::TestCase
  fixtures_none!

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
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "session-1",
        access_claims: { "sub" => "123" },
      ),
    )
    Actor.install_context!(preferences: preference)
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    assert_equal "account-1", Actor.account
    assert_equal "tenant-1", Actor.tenant
    assert_equal :app, Actor.tld
    assert_equal "session-1", Actor.authn.login_public_id
    assert_equal({ "sub" => "123" }, Actor.authn.access_claims)
    assert_equal preference, Actor.preferences
    assert_equal "trace-1", Actor.trace_id
    assert_equal "span-1", Actor.span_id
  end

  test "old authentication and preference compatibility readers are removed" do
    assert_not_respond_to Actor, :authentication
    assert_not_respond_to Actor, :authentication=
    assert_not_respond_to Actor, :preference
    assert_not_respond_to Actor, :preference=
  end

  test "install context does not accept old authentication and preference keys" do
    assert_raises(ArgumentError) do
      Actor.install_context!(authentication: Actor::Authentication::NULL)
    end

    assert_raises(ArgumentError) do
      Actor.install_context!(preference: Actor::Preference::NULL)
    end
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
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "session-1",
        access_claims: { "sub" => "123" },
      ),
    )
    Actor.configuration = Actor::Configuration.new(foo: "bar")
    Actor.install_context!(preferences: Actor::Preference.new(language: "en"))
    Actor.trace_id = "trace-1"
    Actor.span_id = "span-1"

    Actor.clear

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.trace_id
    assert_nil Actor.span_id
  end

  test "authentication access claims are recursively frozen" do
    Actor.install_context!(
      authn: Actor::Authentication.new(
        access_claims: { "scp" => ["read:self"], "prf" => { "lx" => "ja" } },
      ),
    )

    assert_predicate Actor.authn.access_claims, :frozen?
    assert_predicate Actor.authn.access_claims["scp"], :frozen?
    assert_predicate Actor.authn.access_claims["prf"], :frozen?
  end

  test "anonymous aliases the unauthenticated state" do
    assert_predicate Actor, :anonymous?
    assert_not_predicate Actor, :user?
    assert_not_predicate Actor, :staff?

    Actor.actor_type = :client

    assert_not_predicate Actor, :anonymous?
  end

  test "user predicate aliases client actor" do
    Actor.actor_type = :client

    assert_predicate Actor, :user?
    assert_not_predicate Actor, :staff?
  end

  test "staff predicate aliases operator actor" do
    Actor.actor_type = :operator

    assert_predicate Actor, :staff?
    assert_not_predicate Actor, :user?
  end

  test "step up predicates are false when no step up is required" do
    assert_equal Actor::StepUp::NULL, Actor.step_up
    assert_not_predicate Actor, :step_up_fresh?
    assert_not_predicate Actor, :requires_step_up?
  end

  test "requires step up is true when a scope is required but unsatisfied" do
    Actor.install_context!(
      step_up: Actor::StepUp::NULL.with(scope: "settings_email", satisfied: false),
    )

    assert_predicate Actor, :requires_step_up?
    assert_not_predicate Actor, :step_up_fresh?
  end

  test "step up fresh is true and requires step up is false when satisfied" do
    Actor.install_context!(
      step_up: Actor::StepUp::NULL.with(scope: "settings_email", satisfied: true),
    )

    assert_predicate Actor, :step_up_fresh?
    assert_not_predicate Actor, :requires_step_up?
  end
end
