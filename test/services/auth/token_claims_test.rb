# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class TokenClaimsTest < ActiveSupport::TestCase
    DummyResource = Struct.new(:id)

    def setup_token_claims_payload
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )
      [payload, issued_at]
    end

    test "build includes subject and actor claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal 42, payload["sub"]
      assert_equal "user", payload["act"]
    end

    test "build includes session id claim" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal "sess_abc", payload["sid"]
    end

    test "build includes timestamp claims" do
      payload, issued_at = setup_token_claims_payload

      assert_equal unix_timestamp(issued_at), payload["iat"]
      assert_equal unix_timestamp(issued_at + 10.minutes), payload["exp"]
    end

    test "build excludes nbf claim" do
      payload, _issued_at = setup_token_claims_payload

      assert_nil payload["nbf"], "nbf should not be included"
    end

    test "build excludes prf claim when preferences not provided" do
      payload, _issued_at = setup_token_claims_payload

      assert_nil payload["prf"], "prf should not be included when no preferences given"
    end

    test "build includes type and issuer claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal "auth-access-token;user", payload["typ"]
      assert_equal Authentication::Base::JwtConfiguration.issuer("user"), payload["iss"]
    end

    test "build includes audience and jti claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal Authentication::Base::JwtConfiguration.audiences("user"), payload["aud"]
      assert_predicate payload["jti"], :present?
    end

    test "build uses explicit expires_at when provided" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      expires_at = issued_at + 5.minutes
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        expires_at: expires_at,
      )

      assert_equal unix_timestamp(expires_at), payload["exp"]
    end

    test "extractors return nil when payload is nil" do
      assert_nil Auth::TokenClaims.subject(nil)
      assert_nil Auth::TokenClaims.actor(nil)
      assert_nil Auth::TokenClaims.session_id(nil)
      assert_nil Auth::TokenClaims.jti(nil)
    end

    test "build does not include prf claim when preferences is nil" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )

      assert_nil payload["prf"], "auth JWT should not contain preference data when nil"
    end

    test "build includes prf claim when preferences hash provided" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      prefs = { "lx" => "en", "ri" => "us", "tz" => "America/New_York", "ct" => "dr" }
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        preferences: prefs,
      )

      assert_equal prefs, payload["prf"]
    end

    test "build excludes prf claim when preferences is empty hash" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        preferences: {},
      )

      assert_nil payload["prf"], "prf should not be included for empty preferences"
    end

    test "build excludes prf claim when preferences is not a hash" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        preferences: "invalid",
      )

      assert_nil payload["prf"], "prf should not be included for non-hash preferences"
    end

    test "preferences extractor reads prf claim" do
      payload = { "prf" => { "lx" => "ja", "ri" => "jp" } }

      assert_equal({ "lx" => "ja", "ri" => "jp" }, Auth::TokenClaims.preferences(payload))
    end

    test "preferences extractor returns nil when prf absent" do
      assert_nil Auth::TokenClaims.preferences({})
      assert_nil Auth::TokenClaims.preferences(nil)
    end

    test "prf claim roundtrips through Current::Preference.from_jwt" do
      prefs = { "lx" => "en", "ri" => "us", "tz" => "America/New_York", "ct" => "dr" }
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        preferences: prefs,
      )

      pref = Current::Preference.from_jwt(payload["prf"])

      assert_equal "en", pref.language
      assert_equal "us", pref.region
      assert_equal "America/New_York", pref.timezone
      assert_equal "dr", pref.theme
      assert_predicate pref, :dark_mode?
      assert_not_predicate pref, :null?
    end

    test "build includes cnf.jkt when dpop_jkt provided" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        dpop_jkt: "thumb456",
      )

      assert_equal({ "jkt" => "thumb456" }, payload["cnf"])
    end

    test "build backward compatible with session_public_id parameter" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = Auth::TokenClaims.build(
        resource: DummyResource.new(42),
        session_public_id: "legacy_sid",
        resource_type: "user",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )

      assert_equal "legacy_sid", payload["sid"]
    end

    private

    def unix_timestamp(value)
      value.to_i
    end
  end
end
