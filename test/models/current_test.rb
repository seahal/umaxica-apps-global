# typed: false
# frozen_string_literal: true

require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "defaults for unauthenticated state" do
    assert_equal Unauthenticated, Current.actor
    assert_equal :unauthenticated, Current.actor_type
    assert_equal Current::Preference::NULL, Current.preference
    assert_predicate Current, :unauthenticated?
    assert_not Current.authenticated?
    assert_nil Current.user
    assert_nil Current.staff
    assert_nil Current.customer
  end

  test "setting user actor" do
    user = User.new(id: 123)
    Current.actor = user
    Current.actor_type = :user

    assert_equal user, Current.actor
    assert_equal :user, Current.actor_type
    assert_predicate Current, :user?
    assert_predicate Current, :authenticated?
    assert_equal user, Current.user
    assert_not Current.unauthenticated?
  end

  test "setting staff actor" do
    staff = Staff.new(id: 456)
    Current.actor = staff
    Current.actor_type = :staff

    assert_equal staff, Current.actor
    assert_equal :staff, Current.actor_type
    assert_predicate Current, :staff?
    assert_predicate Current, :authenticated?
    assert_equal staff, Current.staff
  end

  test "setting customer actor" do
    customer = Customer.new(id: 789)
    Current.actor = customer
    Current.actor_type = :customer

    assert_equal customer, Current.actor
    assert_equal :customer, Current.actor_type
    assert_predicate Current, :customer?
    assert_predicate Current, :authenticated?
    assert_equal customer, Current.customer
  end

  test "resets preference to NULL" do
    Current.preference = Current::Preference.new(language: "en")

    assert_equal "en", Current.preference.language

    Current.reset

    assert_equal Current::Preference::NULL, Current.preference
  end

  test "preference null object behavior" do
    pref = Current::Preference::NULL

    assert_predicate pref, :null?
    assert_equal :ja, pref.locale
    assert_equal "Asia/Tokyo", pref.time_zone.name
    assert_predicate pref, :system_theme?
    assert_not pref.dark_mode?
  end

  test "preference from jwt" do
    claim = { "lx" => "en", "ri" => "us", "tz" => "UTC", "ct" => "dr" }
    pref = Current::Preference.from_jwt(claim)

    assert_equal "en", pref.language
    assert_equal :en, pref.locale
    assert_equal "us", pref.region
    assert_equal "UTC", pref.time_zone.name
    assert_predicate pref, :dark_mode?
    assert_not pref.null?
  end

  test "preference handles custom locale and cookie object values" do
    cookie_source = Struct.new(:consented, :functional, :performant, :targetable, :consent_version, :consented_at)
      .new(true, true, true, false, "2.0", Time.current)
    pref = Current::Preference.new(language: "fr").with_cookie(cookie_source)

    assert_equal :fr, pref.locale
    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
    assert_predicate pref.cookie, :performant?
    assert_not pref.cookie.targetable?
  end

  test "preference blank cookie object becomes null cookie" do
    pref = Current::Preference.new.with_cookie(nil)

    assert_equal Current::Preference::NULL_COOKIE, pref.cookie
  end

  test "preference theme predicates" do
    assert_predicate Current::Preference.new(theme: "dr"), :dark_mode?
    assert_predicate Current::Preference.new(theme: "li"), :light_mode?
    assert_predicate Current::Preference.new(theme: "sy"), :system_theme?
  end

  test "preference to_h" do
    pref = Current::Preference.new(language: "en", theme: "dr")
    hash = pref.to_h

    assert_equal "en", hash[:language]
    assert_equal "dr", hash[:theme]
    assert_not hash[:consented]
  end

  test "cookie consent define" do
    cookie = Current::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: "1.0", consented_at: Time.current,
    )

    assert_predicate cookie, :consented?
    assert_predicate cookie, :functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
  end
end
