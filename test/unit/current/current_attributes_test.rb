# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorAttributesTest < ActiveSupport::TestCase
  setup { Actor.reset }
  teardown { Actor.reset }

  test "reset clears all attributes" do
    Actor.actor = "some_user"
    Actor.actor_type = :user
    Actor.session = "session_123"
    Actor.token = { "sub" => 1 }
    Actor.surface = :app
    Actor.domain = :app
    Actor.preference = Actor::Preference.new(language: "en")

    Actor.reset

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_nil Actor.surface
    assert_nil Actor.domain
    assert_predicate Actor.preference, :null?
  end

  test "user? and operator? reflect actor_type" do
    Actor.actor_type = :operator

    assert_predicate Actor, :operator?
    assert_not Actor.user?
    assert_nil Actor.user

    Actor.actor_type = :user

    assert_predicate Actor, :user?
    assert_not Actor.operator?
    assert_nil Actor.operator
  end

  test "user and staff return actor for matching actor_type" do
    user = Object.new
    staff = Object.new

    Actor.actor = user
    Actor.actor_type = :user

    assert_equal user, Actor.user
    assert_nil Actor.operator

    Actor.actor = staff
    Actor.actor_type = :operator

    assert_equal staff, Actor.operator
    assert_nil Actor.user
  end

  test "preference defaults to NULL" do
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_predicate Actor.preference, :null?
    assert_equal "ja", Actor.preference.language # Safe default
  end

  test "domain can be set" do
    Actor.domain = :app

    assert_equal :app, Actor.domain

    Actor.domain = :org

    assert_equal :org, Actor.domain
  end

  test "surface can be set" do
    Actor.surface = :app

    assert_equal :app, Actor.surface
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
    payload = { "sub" => 42, "act" => "user" }
    Actor.token = payload

    assert_equal payload, Actor.token
  end
end
