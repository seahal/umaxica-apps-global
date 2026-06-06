# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceJwtAndColorThemeTest < ActiveSupport::TestCase
  test "THEME_SHORT_MAP contains correct mappings" do
    assert_equal "li", PreferenceBase::THEME_SHORT_MAP["light"]
    assert_equal "dr", PreferenceBase::THEME_SHORT_MAP["dark"]
    assert_equal "sy", PreferenceBase::THEME_SHORT_MAP["system"]
  end

  test "THEME_OPTION_MAP contains correct mappings" do
    assert_equal "light", PreferenceBase::THEME_OPTION_MAP["li"]
    assert_equal "dark", PreferenceBase::THEME_OPTION_MAP["dr"]
    assert_equal "system", PreferenceBase::THEME_OPTION_MAP["sy"]
  end
end

class PreferenceOptionMappingTest < ActiveSupport::TestCase
  test "ACCESS_TOKEN_TTL is 7 days" do
    assert_equal 7.days, PreferenceBase::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL is 400 days" do
    assert_equal 400.days, PreferenceBase::REFRESH_TOKEN_TTL
  end

  test "THEME_COOKIE_KEY is correct" do
    assert_equal "ct", PreferenceBase::THEME_COOKIE_KEY
  end

  test "LANGUAGE_COOKIE_KEY is correct" do
    assert_equal "language", PreferenceBase::LANGUAGE_COOKIE_KEY
  end

  test "TIMEZONE_COOKIE_KEY is correct" do
    assert_equal "tz", PreferenceBase::TIMEZONE_COOKIE_KEY
  end
end

class PreferenceJwtConfigurationTest < ActiveSupport::TestCase
  test "jwt configuration reads environment values and normalizes audiences" do
    with_env(
      "PREFERENCE_JWT_ACTIVE_KID" => "kid-1",
      "PREFERENCE_JWT_LEEWAY_SECONDS" => "45",
      "PREFERENCE_JWT_ISSUER" => "jit-test",
      "PREFERENCE_JWT_AUDIENCES" => "app.localhost, org.localhost , ,com.localhost",
    ) do
      assert_equal JitSecurityJwtRegistry.issuer("preference").current_kid,
                   PreferenceJwtConfiguration.active_kid
      assert_equal 45, PreferenceJwtConfiguration.leeway_seconds
      assert_equal "jit-test", PreferenceJwtConfiguration.issuer
      assert_equal %w(app.localhost org.localhost com.localhost), PreferenceJwtConfiguration.audiences
    end
  end

  test "jwt configuration parsing helpers handle invalid input safely" do
    assert_equal({}, PreferenceJwtConfiguration.send(:parse_keyset, nil))
    assert_equal({}, PreferenceJwtConfiguration.send(:parse_keyset, "[]"))
    assert_equal({}, PreferenceJwtConfiguration.send(:parse_keyset, "{"))
    assert_nil PreferenceJwtConfiguration.send(:decode_key, nil)
    assert_equal({}, PreferenceJwtConfiguration.parse_header("invalid.jwt"))
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

class PreferenceTokenTest < ActiveSupport::TestCase
  test "extract helpers and audience normalization handle common shapes" do
    payload = {
      "preferences" => { "ct" => "dr" },
      "public_id" => "pref_123",
      "preference_type" => "app",
      "jti" => "jti-1",
    }

    assert_equal({ "ct" => "dr" }, PreferenceToken.extract_preferences(payload))
    assert_equal "pref_123", PreferenceToken.extract_public_id(payload)
    assert_equal "app", PreferenceToken.extract_preference_type(payload)
    assert_equal "jti-1", PreferenceToken.extract_jti(payload)
    assert_equal ["app.localhost"], PreferenceToken.send(:normalize_audiences, "app.localhost")
    assert_equal %w(app.localhost org.localhost),
                 PreferenceToken.send(:normalize_audiences, %w(app.localhost org.localhost))
    assert_equal [], PreferenceToken.send(:normalize_audiences, 123)
  end

  test "valid_header requires expected algorithm and type" do
    assert PreferenceToken.send(
      :valid_header?,
      { "alg" => PreferenceToken::JWT_ALGORITHM, "kid" => "kid-1", "typ" => PreferenceToken::TOKEN_TYPE },
    )
    assert_not PreferenceToken.send(:valid_header?, {})
  end

  test "host_matches handles direct and nested hosts" do
    assert PreferenceToken.send(:host_matches?, "app.localhost", "app.localhost")
    assert PreferenceToken.send(:host_matches?, "app.localhost", "id.app.localhost")
    assert_not PreferenceToken.send(:host_matches?, "app.localhost", "evil.localhost")
  end

  test "token issued on id host decodes on same TLD sibling when audience is configured" do
    previous = ENV["PREFERENCE_JWT_AUDIENCES"]
    ENV["PREFERENCE_JWT_AUDIENCES"] = "umaxica.app"
    token = PreferenceToken.encode(
      { "lx" => "ja" },
      host: "id.umaxica.app",
      preference_type: "AppPreference",
      public_id: "pref_123",
      jti: "jti_123",
    )

    assert PreferenceToken.decode(token, host: "id.umaxica.app")
    assert PreferenceToken.decode(token, host: "www.umaxica.app")
  ensure
    ENV["PREFERENCE_JWT_AUDIENCES"] = previous
  end

  test "audience_matches handles allowed and rejected audiences" do
    assert PreferenceToken.send(:audience_matches?, ["app.localhost"], "id.app.localhost")
    assert_not PreferenceToken.send(:audience_matches?, ["app.localhost"], "evil.localhost")
  end

  test "validate_payload accepts matching payload" do
    payload = {
      "typ" => PreferenceToken::TOKEN_TYPE,
      "host" => "app.localhost",
      "aud" => ["app.localhost"],
    }

    assert_equal payload, PreferenceToken.send(:validate_payload, payload, "id.app.localhost")
  end

  test "validate_payload rejects invalid type host and audience" do
    payload = {
      "typ" => PreferenceToken::TOKEN_TYPE,
      "host" => "app.localhost",
      "aud" => ["app.localhost"],
    }

    assert_nil PreferenceToken.send(:validate_payload, payload.merge("typ" => "wrong"), "id.app.localhost")
    assert_nil PreferenceToken.send(
      :validate_payload, payload.merge("host" => "evil.localhost"),
      "id.app.localhost",
    )
    assert_nil PreferenceToken.send(
      :validate_payload, payload.merge("aud" => ["evil.localhost"]),
      "id.app.localhost",
    )
  end

  test "invalid header reports precise anomaly reasons" do
    reasons = []

    reporter =
      lambda do |**kwargs|
        reasons << kwargs[:reason]
      end

    JitSecurityJwtAnomalyReporter.stub(:report_preference, reporter) do
      PreferenceToken.send(:report_invalid_header, host: "app.localhost", header: {})
      PreferenceToken.send(
        :report_invalid_header, host: "app.localhost",
                                header: {
                                  "alg" => PreferenceToken::JWT_ALGORITHM,
                                  "typ" => PreferenceToken::TOKEN_TYPE,
                                },
      )
      PreferenceToken.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => "none", "kid" => "kid-1", "typ" => PreferenceToken::TOKEN_TYPE },
      )
      PreferenceToken.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => "HS256", "kid" => "kid-1", "typ" => PreferenceToken::TOKEN_TYPE },
      )
      PreferenceToken.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => PreferenceToken::JWT_ALGORITHM, "kid" => "kid-1" },
      )
      PreferenceToken.send(
        :report_invalid_header, host: "app.localhost",
                                header: {
                                  "alg" => PreferenceToken::JWT_ALGORITHM,
                                  "kid" => "kid-1",
                                  "typ" => "wrong",
                                },
      )
    end

    assert_equal %w(MALFORMED_TOKEN MISSING_KID ALG_NONE ALG_MISMATCH MISSING_TYP TYP_MISMATCH), reasons
  end

  test "invalid payload, claim, and decode errors report anomaly reasons" do
    reasons = []

    reporter =
      lambda do |**kwargs|
        reasons << kwargs[:reason]
      end

    JitSecurityJwtAnomalyReporter.stub(:report_preference, reporter) do
      PreferenceToken.send(
        :report_invalid_payload, host: "app.localhost", header: {}, payload: { "typ" => "wrong" },
      )
      token_type = PreferenceToken::TOKEN_TYPE
      PreferenceToken.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "evil.localhost",
                                   "aud" => ["app.localhost"],
                                 },
      )
      PreferenceToken.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "app.localhost",
                                   "aud" => ["evil.localhost"],
                                 },
      )
      PreferenceToken.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "app.localhost",
                                   "aud" => ["app.localhost"],
                                 },
      )
      PreferenceToken.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::InvalidIssuerError.new("bad iss"),
      )
      PreferenceToken.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::InvalidIatError.new("bad iat"),
      )
      PreferenceToken.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::ImmatureSignature.new("too early"),
      )
    end

    JitSecurityJwtAnomalyReporter.stub(:reason_for_missing_claim, "MISSING_PUBLIC_ID") do
      JitSecurityJwtAnomalyReporter.stub(:report_preference, reporter) do
        PreferenceToken.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Missing required claim public_id"),
        )
        PreferenceToken.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Signature verification failed"),
        )
        PreferenceToken.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Not enough or too many segments"),
        )
        PreferenceToken.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("misc"),
        )
      end
    end

    assert_equal(
      %w(
        TYP_MISMATCH
        HOST_MISMATCH
        AUD_MISMATCH
        OTHER
        ISS_MISMATCH
        IAT_INVALID
        IMMATURE
        MISSING_PUBLIC_ID
        SIGNATURE_INVALID
        MALFORMED_TOKEN
        DECODE_ERROR
      ),
      reasons,
    )
  end
end
