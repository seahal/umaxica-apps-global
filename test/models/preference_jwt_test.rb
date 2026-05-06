# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceJwtTest < ActiveSupport::TestCase
  test "parse_header rescues DecodeError" do
    assert_equal({}, Preference::JwtConfiguration.parse_header("invalid.token.format"))
  end

  test "private_key returns nil if not active" do
    Preference::JwtConfiguration.stub(:active_kid, "non_existent") do
      assert_nil Preference::JwtConfiguration.private_key
    end
  end

  test "parse_keyset rescues JSON::ParserError and returns empty hash" do
    assert_equal({}, Preference::JwtConfiguration.send(:parse_keyset, "invalid_json"))
  end

  test "parse_keyset returns empty hash for non-hash JSON" do
    assert_equal({}, Preference::JwtConfiguration.send(:parse_keyset, "[\"array\"]"))
  end

  test "decode_key rescues PKeyError" do
    assert_nil Preference::JwtConfiguration.send(:decode_key, Base64.encode64("invalid_der_data"))
  end

  test "Token.encode returns nil on error" do
    Preference::JwtConfiguration.stub(:private_key_for_active, nil) do
      assert_nil Preference::Token.encode({}, host: "host", preference_type: "type", public_id: "id", jti: "jti")
    end
  end

  test "Token.decode returns nil for expired token" do
    payload = {
      preferences: {},
      host: "host",
      preference_type: "type",
      public_id: "id",
      jti: "jti",
      typ: Preference::Token::TOKEN_TYPE,
      iss: Preference::JwtConfiguration.issuer,
      aud: Preference::JwtConfiguration.audience_for("host"),
      iat: 1.day.ago.to_i,
      exp: 1.hour.ago.to_i,
    }
    key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode(
      payload, key, Preference::Token::JWT_ALGORITHM,
      { kid: "default", typ: Preference::Token::TOKEN_TYPE },
    )

    Preference::JwtConfiguration.stub(:public_key_for, key) do
      assert_nil Preference::Token.decode(token, host: "host")
    end
  end
end
