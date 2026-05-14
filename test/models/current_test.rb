# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorContextTest < ActiveSupport::TestCase
  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  test "defaults for unauthenticated state" do
    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_predicate Actor, :unauthenticated?
    assert_not Actor.authenticated?
    assert_nil Actor.user
    assert_nil Actor.operator
    assert_nil Actor.visitor
  end

  test "setting user actor" do
    user = User.new(id: 123)
    Actor.actor = user
    Actor.actor_type = :user

    assert_equal user, Actor.actor
    assert_equal :user, Actor.actor_type
    assert_predicate Actor, :user?
    assert_predicate Actor, :authenticated?
    assert_equal user, Actor.user
    assert_not Actor.unauthenticated?
  end

  test "setting staff actor" do
    staff = Operator.new(id: 456)
    Actor.actor = staff
    Actor.actor_type = :operator

    assert_equal staff, Actor.actor
    assert_equal :operator, Actor.actor_type
    assert_predicate Actor, :operator?
    assert_predicate Actor, :authenticated?
    assert_equal staff, Actor.operator
  end

  test "setting visitor actor" do
    visitor = Visitor.new(id: 789)
    Actor.actor = visitor
    Actor.actor_type = :visitor

    assert_equal visitor, Actor.actor
    assert_equal :visitor, Actor.actor_type
    assert_predicate Actor, :visitor?
    assert_predicate Actor, :authenticated?
    assert_equal visitor, Actor.visitor
  end

  test "resets preference to NULL" do
    Actor.preference = Actor::Preference.new(language: "en")

    assert_equal "en", Actor.preference.language

    Actor.reset

    assert_equal Actor::Preference::NULL, Actor.preference
  end

  test "preference null object behavior" do
    pref = Actor::Preference::NULL

    assert_predicate pref, :null?
    assert_equal :ja, pref.locale
    assert_equal "Asia/Tokyo", pref.time_zone.name
    assert_predicate pref, :system_theme?
    assert_not pref.dark_mode?
  end

  test "preference from jwt" do
    claim = { "lx" => "en", "ri" => "us", "tz" => "UTC", "ct" => "dr" }
    pref = Actor::Preference.from_jwt(claim)

    assert_equal "en", pref.language
    assert_equal :en, pref.locale
    assert_equal "us", pref.region
    assert_equal "UTC", pref.time_zone.name
    assert_predicate pref, :dark_mode?
    assert_not pref.null?
  end

  test "preference exposes public_id" do
    pref = Actor::Preference.new(public_id: "pref-public")

    assert_equal "pref-public", pref.public_id
    assert_equal "pref-public", pref.with_cookie(nil).public_id
  end

  test "preference handles custom locale and cookie object values" do
    cookie_source = Struct.new(:consented, :functional, :performant, :targetable, :consent_version, :consented_at)
      .new(true, true, true, false, "2.0", Time.current)
    pref = Actor::Preference.new(language: "fr").with_cookie(cookie_source)

    assert_equal :fr, pref.locale
    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
    assert_predicate pref.cookie, :performant?
    assert_not pref.cookie.targetable?
  end

  test "preference blank cookie object becomes null cookie" do
    pref = Actor::Preference.new.with_cookie(nil)

    assert_equal Actor::Preference::NULL_COOKIE, pref.cookie
  end

  test "preference theme predicates" do
    assert_predicate Actor::Preference.new(theme: "dr"), :dark_mode?
    assert_predicate Actor::Preference.new(theme: "li"), :light_mode?
    assert_predicate Actor::Preference.new(theme: "sy"), :system_theme?
  end

  test "preference to_h" do
    pref = Actor::Preference.new(language: "en", theme: "dr")
    hash = pref.to_h

    assert_equal "en", hash[:language]
    assert_equal "dr", hash[:theme]
    assert_not hash[:consented]
  end

  test "cookie consent define" do
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: "1.0", consented_at: Time.current,
    )

    assert_predicate cookie, :consented?
    assert_predicate cookie, :functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
  end
end
