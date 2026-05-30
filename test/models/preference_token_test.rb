# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require_relative "../../app/controllers/concerns/preference/base"

class PreferenceTokenModelTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    @host = "example.com".freeze
    @preferences = {
      "lx" => "en",
      "ri" => "us",
      "tz" => "utc",
      "ct" => "dr",
    }.freeze
    @preference_type = "AppPreference".freeze
    @public_id = "pref_public_id".freeze
    @jti = "test-jti-#{SecureRandom.uuid}".freeze
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_key = @private_key
    @issuer = "jit-preference".freeze
    @audiences = ["example.com"].freeze
  end

  test "encode returns a token string" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_not_nil token
      assert_kind_of String, token
    end
  end

  test "encode returns nil for blank preferences or host" do
    with_jwt_keys do
      assert_nil Preference::Token.encode(
        {},
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      assert_nil Preference::Token.encode(
        @preferences,
        host: nil,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
    end
  end

  test "decode returns payload for valid token and host" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload = Preference::Token.decode(token, host: @host)

      assert_kind_of Hash, payload
      assert_equal @host, payload["host"]
      assert_equal @preferences, payload["preferences"]
      assert_equal @preference_type, payload["preference_type"]
      assert_equal @public_id, payload["public_id"]
      assert_equal @jti, payload["jti"]
      assert_equal Preference::Token::TOKEN_TYPE, payload["typ"]
    end
  end

  test "decode returns nil for mismatched host" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_nil Preference::Token.decode(token, host: "other.com")
    end
  end

  test "decode accepts subdomain host for audience" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      payload = Preference::Token.decode(token, host: "app.example.com")

      assert_kind_of Hash, payload
    end
  end

  test "decode returns nil for invalid token" do
    with_jwt_keys do
      assert_nil Preference::Token.decode("invalid.token", host: @host)
    end
  end

  test "decode returns nil for blank inputs" do
    with_jwt_keys do
      assert_nil Preference::Token.decode(nil, host: @host)
      assert_nil Preference::Token.decode("token", host: nil)
    end
  end

  test "extract_preferences returns preferences hash from payload" do
    payload = { "preferences" => @preferences }

    assert_equal @preferences, Preference::Token.extract_preferences(payload)
  end

  test "extract_preferences returns empty hash for invalid payload" do
    assert_empty(Preference::Token.extract_preferences(nil))
    assert_empty(Preference::Token.extract_preferences({}))
  end

  test "encode returns nil for blank jti" do
    with_jwt_keys do
      assert_nil Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: nil,
      )
      assert_nil Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: "",
      )
    end
  end

  test "extract_jti returns jti from payload" do
    payload = { "jti" => @jti }

    assert_equal @jti, Preference::Token.extract_jti(payload)
  end

  test "extract_jti returns nil for invalid payload" do
    assert_nil Preference::Token.extract_jti(nil)
    assert_nil Preference::Token.extract_jti({})
  end

  test "handle invalid signature gracefully" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      tampered_token = token.reverse

      assert_nil Preference::Token.decode(tampered_token, host: @host)
    end
  end

  test "decode rejects HS256 token even with same payload" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, "secret_credential", "HS256", { typ: Preference::Token::TOKEN_TYPE })

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects alg none token" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, nil, "none", { typ: Preference::Token::TOKEN_TYPE })

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects missing typ claim" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("typ")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects wrong typ header" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, @private_key, "ES384", { typ: "auth-access-token;client" })

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects wrong issuer" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload["iss"] = "other-issuer"
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects missing aud claim" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("aud")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects missing public_id claim" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("public_id")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects missing jti claim" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("jti")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "decode rejects missing preference_type claim" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("preference_type")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test "encode returns nil and logs error on StandardError" do
    # Temporarily override with faulty implementation
    original = Preference::JwtConfiguration.method(:private_key_for_active)
    Preference::JwtConfiguration.define_singleton_method(:private_key_for_active) { raise StandardError, "forced error" }
    begin
      assert_nil Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
    ensure
      Preference::JwtConfiguration.define_singleton_method(:private_key_for_active, &original)
    end
  end

  test "decode returns nil and logs error on StandardError" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @preferences,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      original = Preference::JwtConfiguration.method(:public_key_for)
      Preference::JwtConfiguration.define_singleton_method(:public_key_for) { |_kid| raise StandardError, "forced error" }
      begin
        assert_nil Preference::Token.decode(token, host: @host)
      ensure
        Preference::JwtConfiguration.define_singleton_method(:public_key_for, original)
      end
    end
  end

  private

  def with_jwt_keys
    # Manually stub using define_singleton_method to avoid Minitest stub issues with modules
    # if methods are missing or weirdly defined.

    methods = %i(private_key public_key private_key_for_active public_key_for active_kid issuer audiences)
    originals = {}

    methods.each do |m|
      originals[m] =
        if Preference::JwtConfiguration.respond_to?(m)
          Preference::JwtConfiguration.method(m)
        else
          proc { raise RuntimeError, "Method #{m} was missing!" }
        end
    end

    # Capture values in local variables for block closure
    priv_key = @private_key
    pub_key = @public_key
    iss = @issuer
    auds = @audiences

    # Define stubs
    Preference::JwtConfiguration.define_singleton_method(:private_key) { priv_key }
    Preference::JwtConfiguration.define_singleton_method(:public_key) { pub_key }
    Preference::JwtConfiguration.define_singleton_method(:private_key_for_active) { priv_key }
    Preference::JwtConfiguration.define_singleton_method(:public_key_for) { |_kid| pub_key }
    Preference::JwtConfiguration.define_singleton_method(:active_kid) { "default" }
    Preference::JwtConfiguration.define_singleton_method(:issuer) { iss }
    Preference::JwtConfiguration.define_singleton_method(:audiences) { auds }

    yield
  ensure
    # Restore originals
    methods.each do |m|
      if originals[m]
        Preference::JwtConfiguration.define_singleton_method(m, &originals[m])
      end
    end
  end
end
