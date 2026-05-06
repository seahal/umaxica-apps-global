# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceColorThemeTest < ActiveSupport::TestCase
  test "COLORTHEME_SHORT_MAP contains correct mappings" do
    assert_equal "li", Preference::Base::COLORTHEME_SHORT_MAP["light"]
    assert_equal "dr", Preference::Base::COLORTHEME_SHORT_MAP["dark"]
    assert_equal "sy", Preference::Base::COLORTHEME_SHORT_MAP["system"]
  end

  test "COLORTHEME_OPTION_MAP contains correct mappings" do
    assert_equal "light", Preference::Base::COLORTHEME_OPTION_MAP["li"]
    assert_equal "dark", Preference::Base::COLORTHEME_OPTION_MAP["dr"]
    assert_equal "system", Preference::Base::COLORTHEME_OPTION_MAP["sy"]
  end
end

class PreferenceOptionMappingTest < ActiveSupport::TestCase
  test "ACCESS_TOKEN_TTL is 7 days" do
    assert_equal 7.days, Preference::Base::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL is 400 days" do
    assert_equal 400.days, Preference::Base::REFRESH_TOKEN_TTL
  end

  test "THEME_COOKIE_KEY is correct" do
    assert_equal "ct", Preference::Base::THEME_COOKIE_KEY
  end

  test "LANGUAGE_COOKIE_KEY is correct" do
    assert_equal "language", Preference::Base::LANGUAGE_COOKIE_KEY
  end

  test "TIMEZONE_COOKIE_KEY is correct" do
    assert_equal "tz", Preference::Base::TIMEZONE_COOKIE_KEY
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
      assert_equal "kid-1", Preference::JwtConfiguration.active_kid
      assert_equal 45, Preference::JwtConfiguration.leeway_seconds
      assert_equal "jit-test", Preference::JwtConfiguration.issuer
      assert_equal %w(app.localhost org.localhost com.localhost), Preference::JwtConfiguration.audiences
    end
  end

  test "jwt configuration parsing helpers handle invalid input safely" do
    assert_equal({}, Preference::JwtConfiguration.send(:parse_keyset, nil))
    assert_equal({}, Preference::JwtConfiguration.send(:parse_keyset, "[]"))
    assert_equal({}, Preference::JwtConfiguration.send(:parse_keyset, "{"))
    assert_nil Preference::JwtConfiguration.send(:decode_key, nil)
    assert_equal({}, Preference::JwtConfiguration.parse_header("invalid.jwt"))
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

    assert_equal({ "ct" => "dr" }, Preference::Token.extract_preferences(payload))
    assert_equal "pref_123", Preference::Token.extract_public_id(payload)
    assert_equal "app", Preference::Token.extract_preference_type(payload)
    assert_equal "jti-1", Preference::Token.extract_jti(payload)
    assert_equal ["app.localhost"], Preference::Token.send(:normalize_audiences, "app.localhost")
    assert_equal %w(app.localhost org.localhost),
                 Preference::Token.send(:normalize_audiences, %w(app.localhost org.localhost))
    assert_equal [], Preference::Token.send(:normalize_audiences, 123)
  end

  test "valid_header requires expected algorithm and type" do
    assert Preference::Token.send(
      :valid_header?,
      { "alg" => Preference::Token::JWT_ALGORITHM, "kid" => "kid-1", "typ" => Preference::Token::TOKEN_TYPE },
    )
    assert_not Preference::Token.send(:valid_header?, {})
  end

  test "host_matches handles direct and nested hosts" do
    assert Preference::Token.send(:host_matches?, "app.localhost", "app.localhost")
    assert Preference::Token.send(:host_matches?, "app.localhost", "id.app.localhost")
    assert_not Preference::Token.send(:host_matches?, "app.localhost", "evil.localhost")
  end

  test "audience_matches handles allowed and rejected audiences" do
    assert Preference::Token.send(:audience_matches?, ["app.localhost"], "id.app.localhost")
    assert_not Preference::Token.send(:audience_matches?, ["app.localhost"], "evil.localhost")
  end

  test "validate_payload accepts matching payload" do
    payload = {
      "typ" => Preference::Token::TOKEN_TYPE,
      "host" => "app.localhost",
      "aud" => ["app.localhost"],
    }

    assert_equal payload, Preference::Token.send(:validate_payload, payload, "id.app.localhost")
  end

  test "validate_payload rejects invalid type host and audience" do
    payload = {
      "typ" => Preference::Token::TOKEN_TYPE,
      "host" => "app.localhost",
      "aud" => ["app.localhost"],
    }

    assert_nil Preference::Token.send(:validate_payload, payload.merge("typ" => "wrong"), "id.app.localhost")
    assert_nil Preference::Token.send(
      :validate_payload, payload.merge("host" => "evil.localhost"),
      "id.app.localhost",
    )
    assert_nil Preference::Token.send(
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

    Jit::Security::Jwt::AnomalyReporter.stub(:report_preference, reporter) do
      Preference::Token.send(:report_invalid_header, host: "app.localhost", header: {})
      Preference::Token.send(
        :report_invalid_header, host: "app.localhost",
                                header: {
                                  "alg" => Preference::Token::JWT_ALGORITHM,
                                  "typ" => Preference::Token::TOKEN_TYPE,
                                },
      )
      Preference::Token.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => "none", "kid" => "kid-1", "typ" => Preference::Token::TOKEN_TYPE },
      )
      Preference::Token.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => "HS256", "kid" => "kid-1", "typ" => Preference::Token::TOKEN_TYPE },
      )
      Preference::Token.send(
        :report_invalid_header, host: "app.localhost",
                                header: { "alg" => Preference::Token::JWT_ALGORITHM, "kid" => "kid-1" },
      )
      Preference::Token.send(
        :report_invalid_header, host: "app.localhost",
                                header: {
                                  "alg" => Preference::Token::JWT_ALGORITHM,
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

    Jit::Security::Jwt::AnomalyReporter.stub(:report_preference, reporter) do
      Preference::Token.send(
        :report_invalid_payload, host: "app.localhost", header: {}, payload: { "typ" => "wrong" },
      )
      token_type = Preference::Token::TOKEN_TYPE
      Preference::Token.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "evil.localhost",
                                   "aud" => ["app.localhost"],
                                 },
      )
      Preference::Token.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "app.localhost",
                                   "aud" => ["evil.localhost"],
                                 },
      )
      Preference::Token.send(
        :report_invalid_payload, host: "app.localhost", header: {},
                                 payload: {
                                   "typ" => token_type,
                                   "host" => "app.localhost",
                                   "aud" => ["app.localhost"],
                                 },
      )
      Preference::Token.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::InvalidIssuerError.new("bad iss"),
      )
      Preference::Token.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::InvalidIatError.new("bad iat"),
      )
      Preference::Token.send(
        :report_claim_error, host: "app.localhost", header: {},
                             error: JWT::ImmatureSignature.new("too early"),
      )
    end

    Jit::Security::Jwt::AnomalyReporter.stub(:reason_for_missing_claim, "MISSING_PUBLIC_ID") do
      Jit::Security::Jwt::AnomalyReporter.stub(:report_preference, reporter) do
        Preference::Token.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Missing required claim public_id"),
        )
        Preference::Token.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Signature verification failed"),
        )
        Preference::Token.send(
          :report_decode_error, host: "app.localhost", header: {},
                                error: StandardError.new("Not enough or too many segments"),
        )
        Preference::Token.send(
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
