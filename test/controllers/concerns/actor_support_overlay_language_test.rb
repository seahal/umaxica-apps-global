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
  # Minimal includer exposing the private resolver. locale_from_region is not
  # defined here, so locale_from_request_region falls back to its inline map.
  class Harness
    include ActorSupport

    def overlay(context, preference)
      send(:overlay_language, context, preference)
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
end
