# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require_relative "../../app/controllers/concerns/preference/jwt_configuration"
require_relative "../../app/controllers/concerns/preference/token"

class PreferenceTokenServiceTest < ActiveSupport::TestCase
  setup do
    @prefs = { "ct" => "dr" }.freeze
    @host = "example.com".freeze
    @preference_type = "AppPreference".freeze
    @public_id = "pref_public_id".freeze
    @jti = "test-jti-#{SecureRandom.uuid}".freeze
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_key = @private_key
    @issuer = "jit-preference".freeze
    @audiences = ["example.com"].freeze
  end

  test "encodes and decodes token" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_not_nil token

      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal Preference::Token::TOKEN_TYPE, header["typ"]

      decoded = Preference::Token.decode(token, host: @host)

      assert_not_nil decoded
      assert_equal "dr", decoded.dig("preferences", "ct")
      assert_equal @jti, decoded["jti"]
      assert_equal Preference::Token::TOKEN_TYPE, decoded["typ"]
    end
  end

  test "returns nil for invalid token" do
    with_jwt_keys do
      assert_nil Preference::Token.decode("invalid", host: @host)
    end
  end

  test "returns nil for wrong host" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_nil Preference::Token.decode(token, host: "wrong.com")
    end
  end

  test "returns nil for alg none token" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @prefs,
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

  test "returns nil for unknown kid" do
    with_jwt_keys do
      token = Preference::Token.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, @private_key, "ES384", header.merge("kid" => "unknown-kid"))

      assert_nil Preference::Token.decode(tampered, host: @host)
    end
  end

  test ".app token cannot be replayed against the .com surface" do
    audiences = ["id.umaxica.app", "id.umaxica.com"].freeze
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    Preference::JwtConfiguration.stub(:private_key, @private_key) do
      Preference::JwtConfiguration.stub(:public_key, @public_key) do
        Preference::JwtConfiguration.stub(:private_key_for_active, @private_key) do
          Preference::JwtConfiguration.stub(:public_key_for, key_for) do
            Preference::JwtConfiguration.stub(:active_kid, "default") do
              Preference::JwtConfiguration.stub(:issuer, @issuer) do
                Preference::JwtConfiguration.stub(:audiences, audiences) do
                  app_token = Preference::Token.encode(
                    @prefs,
                    host: "id.umaxica.app",
                    preference_type: "AppPreference",
                    public_id: @public_id,
                    jti: @jti,
                  )

                  assert_not_nil app_token
                  assert_nil Preference::Token.decode(app_token, host: "id.umaxica.com"),
                             "audience scoped to .app TLD must not validate on a .com host"
                end
              end
            end
          end
        end
      end
    end
  end

  test "JwtConfiguration.audiences raises when PREFERENCE_JWT_AUDIENCES is missing" do
    original = ENV["PREFERENCE_JWT_AUDIENCES"]
    begin
      ENV.delete("PREFERENCE_JWT_AUDIENCES")
      assert_raises(Preference::JwtConfiguration::MissingAudienceError) do
        Preference::JwtConfiguration.audiences
      end
    ensure
      ENV["PREFERENCE_JWT_AUDIENCES"] = original
    end
  end

  test "audience_for requires a host" do
    Preference::JwtConfiguration.stub(:audiences, ["example.com"]) do
      assert_raises(ArgumentError) { Preference::JwtConfiguration.audience_for(nil) }
      assert_raises(ArgumentError) { Preference::JwtConfiguration.audience_for("") }
    end
  end

  private

  def with_jwt_keys
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    Preference::JwtConfiguration.stub(:private_key, @private_key) do
      Preference::JwtConfiguration.stub(:public_key, @public_key) do
        Preference::JwtConfiguration.stub(:private_key_for_active, @private_key) do
          Preference::JwtConfiguration.stub(:public_key_for, key_for) do
            Preference::JwtConfiguration.stub(:active_kid, "default") do
              Preference::JwtConfiguration.stub(:issuer, @issuer) do
                Preference::JwtConfiguration.stub(:audiences, @audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end
