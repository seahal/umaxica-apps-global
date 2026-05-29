# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit coverage for the request-overlay language resolution priority.
#
# A region context param (e.g. ?ri=jp) may seed the language for a guest with no
# saved preference, but it must never override an explicit `lx` param or a saved
# (non-null) language preference.
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

  def pref(language:, null:)
    Actor::Preference.new(language: language, null: null)
  end

  test "explicit lx param wins over everything" do
    assert_equal "ja", @harness.overlay({ lx: "ja", ri: "us" }, pref(language: "en", null: false))
  end

  test "saved language wins over region param" do
    assert_equal "en", @harness.overlay({ ri: "jp" }, pref(language: "en", null: false))
  end

  test "region seeds language for a null (guest) preference" do
    assert_equal "en", @harness.overlay({ ri: "us" }, pref(language: "ja", null: true))
    assert_equal "ja", @harness.overlay({ ri: "jp" }, pref(language: "en", null: true))
  end

  test "falls back to preference language when no param and no region" do
    assert_equal "en", @harness.overlay({}, pref(language: "en", null: false))
    assert_equal "ja", @harness.overlay({}, pref(language: "ja", null: true))
  end
end
