# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorAttributesTest < ActiveSupport::TestCase
  setup { Actor.reset }
  teardown { Actor.reset }

  test "reset clears all attributes" do
    Actor.actor = "some_user"
    Actor.actor_type = :client
    Actor.session = "session_123"
    Actor.token = { "sub" => 1 }
    Actor.authentication = Actor::Authentication.new(login_public_id: "session_123")
    Actor.configuration = Actor::Configuration.new(foo: "bar")
    Actor.tld = :app
    Actor.preference = Actor::Preference.new(language: "en")

    Actor.reset

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Authentication::NULL, Actor.authentication
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_nil Actor.tld
    assert_predicate Actor.preference, :null?
  end

  test "user? and operator? reflect actor_type" do
    Actor.actor_type = :operator

    assert_predicate Actor, :operator?
    assert_not Actor.client?
    assert_nil Actor.client

    Actor.actor_type = :client

    assert_predicate Actor, :client?
    assert_not Actor.operator?
    assert_nil Actor.operator
  end

  test "user and staff return actor for matching actor_type" do
    user = Object.new
    staff = Object.new

    Actor.actor = user
    Actor.actor_type = :client

    assert_equal user, Actor.client
    assert_nil Actor.operator

    Actor.actor = staff
    Actor.actor_type = :operator

    assert_equal staff, Actor.operator
    assert_nil Actor.client
  end

  test "preference defaults to NULL" do
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_predicate Actor.preference, :null?
    assert_equal "ja", Actor.preference.language # Safe default
  end

  test "tld can be set" do
    Actor.tld = :net

    assert_equal :net, Actor.tld
  end

  test "actor can be set" do
    Actor.actor = "test_actor"

    assert_equal "test_actor", Actor.actor
  end

  test "session can be set" do
    Actor.session = "session_public_id"

    assert_equal "session_public_id", Actor.session
  end

  test "token can be set" do
    payload = { "sub" => 42, "act" => "client" }
    Actor.token = payload

    assert_equal payload, Actor.token
  end
end
