# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit coverage for the request-overlay language resolution priority.
#
# A region context param (e.g. ?ri=jp) may seed the language for a user who has
# not explicitly chosen one, but it must never override an explicit `lx` param or
# a language the user set on purpose (tracked via explicit_fields). Whole-record
# null? is no longer the gate: hydrated preferences are never null because default
# child records always exist, so explicitness is what distinguishes "set" from
# "default-seeded".
class ActorSupportOverlayLanguageTest < ActiveSupport::TestCase
  fixtures_none!

  # Minimal includer exposing the private resolver. locale_from_region is not
  # defined here, so locale_from_request_region falls back to its inline map.
  class Harness
    include ActorSupport

    def overlay(context, preference)
      send(:overlay_language, context, preference)
    end

    attr_writer :requested_context

    def requested_context
      @requested_context || {}
    end

    def overlay_preference(preference)
      send(:preference_with_request_overlay, preference)
    end
  end

  setup { @harness = Harness.new }

  # explicit: list of explicitly-set field names. Pass ["language"] to mark the
  # language as a deliberate user choice.
  def pref(language:, explicit: [], null: false)
    Actor::Preference.new(language: language, null: null, explicit_fields: explicit)
  end

  test "explicit lx param wins over everything" do
    assert_equal "ja",
                 @harness.overlay({ lx: "ja", ri: "us" }, pref(language: "en", explicit: ["language"]))
  end

  test "explicitly saved language wins over region param" do
    assert_equal "en", @harness.overlay({ ri: "jp" }, pref(language: "en", explicit: ["language"]))
  end

  test "region seeds language when language is not explicitly set" do
    # Unset language (default-seeded), non-null hydrated record: ?ri wins.
    assert_equal "en", @harness.overlay({ ri: "us" }, pref(language: "ja", explicit: []))
    assert_equal "ja", @harness.overlay({ ri: "jp" }, pref(language: "en", explicit: []))
  end

  test "region seeds language for a null (guest) preference" do
    assert_equal "en", @harness.overlay({ ri: "us" }, pref(language: "ja", null: true))
    assert_equal "ja", @harness.overlay({ ri: "jp" }, pref(language: "en", null: true))
  end

  test "falls back to preference language when no param and no region" do
    assert_equal "en", @harness.overlay({}, pref(language: "en", explicit: ["language"]))
    assert_equal "ja", @harness.overlay({}, pref(language: "ja", null: true))
  end

  test "request context overlays display preference fields" do
    @harness.requested_context = {
      lx: "en",
      ri: "us",
      tz: "etc/utc",
      ct: "dr",
      cu: "usd",
      df: "us",
      tf: "12",
      mo: "rd",
      dn: "cp",
      ps: "50",
    }
    preference = Actor::Preference.new(
      language: "ja",
      region: "jp",
      timezone: "Asia/Tokyo",
      theme: "sy",
      currency: "jpy",
      date_format: "iso",
      time_format: "24",
      motion: "standard",
      density: "standard",
      page_size: "infinity",
    )

    overlaid = @harness.overlay_preference(preference)

    assert_equal "en", overlaid.language
    assert_equal "us", overlaid.region
    assert_equal "etc/utc", overlaid.timezone
    assert_equal "dr", overlaid.theme
    assert_equal "usd", overlaid.currency
    assert_equal "us", overlaid.date_format
    assert_equal "12", overlaid.time_format
    assert_equal "rd", overlaid.motion
    assert_equal "cp", overlaid.density
    assert_equal "50", overlaid.page_size
  end
end
