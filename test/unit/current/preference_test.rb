# typed: false
# frozen_string_literal: true

require "test_helper"

class Actor::PreferenceTest < ActiveSupport::TestCase
  test "NULL returns safe defaults" do
    pref = Actor::Preference::NULL

    assert_predicate pref, :null?
    assert_equal "ja", pref.language
    assert_equal "jp", pref.region
    assert_equal "Asia/Tokyo", pref.timezone
    assert_equal "sy", pref.theme
    assert_equal :ja, pref.locale
    assert_predicate pref, :system_theme?
    assert_not pref.dark_mode?
    assert_not pref.light_mode?
  end

  test "NULL cookie returns false for all consent flags" do
    cookie = Actor::Preference::NULL.cookie

    assert_not cookie.consented?
    assert_not cookie.functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
    assert_nil cookie.consent_version
    assert_nil cookie.consented_at
  end

  test "custom preference overrides defaults" do
    pref = Actor::Preference.new(
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
    )

    assert_not pref.null?
    assert_equal "en", pref.language
    assert_equal "us", pref.region
    assert_equal "America/New_York", pref.timezone
    assert_equal :en, pref.locale
    assert_predicate pref, :dark_mode?
    assert_not pref.system_theme?
  end

  test "preference with cookie consent" do
    cookie = Actor::Preference::Cookie.new(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: "v1",
      consented_at: Time.zone.parse("2026-01-01"),
    )
    pref = Actor::Preference.new(cookie: cookie)

    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
    assert_not pref.cookie.performant?
    assert_equal "v1", pref.cookie.consent_version
  end

  test "preference is frozen" do
    pref = Actor::Preference.new

    assert_predicate pref, :frozen?
  end

  test "time_zone returns ActiveSupport::TimeZone" do
    pref = Actor::Preference.new(timezone: "America/New_York")

    assert_instance_of ActiveSupport::TimeZone, pref.time_zone
    assert_equal "America/New_York", pref.time_zone.name
  end

  test "time_zone falls back to Asia/Tokyo for unknown zone" do
    pref = Actor::Preference.new(timezone: "Invalid/Zone")

    assert_equal "Asia/Tokyo", pref.time_zone.name
  end

  test "to_h returns preference summary" do
    pref = Actor::Preference.new(language: "en", theme: "li")

    h = pref.to_h

    assert_equal "en", h[:language]
    assert_equal "li", h[:theme]
    assert_not h[:consented]
  end

  test "Actor.preference returns NULL by default" do
    Actor.reset

    assert_equal Actor::Preference::NULL, Actor.preference
    assert_predicate Actor.preference, :null?
  end

  test "Actor.preference can be assigned" do
    Actor.reset
    custom = Actor::Preference.new(language: "en")
    Actor.preference = custom

    assert_equal "en", Actor.preference.language
    assert_not Actor.preference.null?
  ensure
    Actor.reset
  end

  test "from_jwt returns NULL for nil input" do
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt(nil)
  end

  test "from_jwt returns NULL for non-hash input" do
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt("string")
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt(123)
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt([])
  end

  test "from_jwt constructs correct Preference from valid prf hash" do
    prf = { "lx" => "en", "ri" => "us", "tz" => "America/New_York", "ct" => "dr" }
    pref = Actor::Preference.from_jwt(prf)

    assert_not pref.null?
    assert_equal "en", pref.language
    assert_equal "us", pref.region
    assert_equal "America/New_York", pref.timezone
    assert_equal "dr", pref.theme
  end

  test "from_jwt falls back to DEFAULTS for missing keys" do
    prf = { "lx" => "en" } # Only language provided
    pref = Actor::Preference.from_jwt(prf)

    assert_equal "en", pref.language
    assert_equal "jp", pref.region # DEFAULTS[:region]
    assert_equal "Asia/Tokyo", pref.timezone # DEFAULTS[:timezone]
    assert_equal "sy", pref.theme # DEFAULTS[:theme]
  end

  test "from_jwt handles empty hash" do
    pref = Actor::Preference.from_jwt({})

    assert_equal "ja", pref.language
    assert_equal "jp", pref.region
    assert_equal "Asia/Tokyo", pref.timezone
    assert_equal "sy", pref.theme
  end

  test "from_jwt with cookie parameter" do
    cookie = Actor::Preference::Cookie.new(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: "v1",
      consented_at: Time.zone.parse("2026-01-01"),
    )
    prf = { "lx" => "en" }
    pref = Actor::Preference.from_jwt(prf, cookie: cookie)

    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
  end

  test "with_cookie keeps preference values and updates cookie state" do
    pref = Actor::Preference.new(language: "en", region: "us", timezone: "America/New_York", theme: "dr")

    updated = pref.with_cookie(
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: "v2",
    )

    assert_equal "en", updated.language
    assert_equal "us", updated.region
    assert_equal "America/New_York", updated.timezone
    assert_equal "dr", updated.theme
    assert_predicate updated.cookie, :consented?
    assert_predicate updated.cookie, :functional?
    assert_not updated.cookie.performant?
    assert_predicate updated.cookie, :targetable?
    assert_equal "v2", updated.cookie.consent_version
  end
end
