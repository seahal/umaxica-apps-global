# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require_relative "../../app/controllers/concerns/preference_jwt_configuration"
require_relative "../../app/controllers/concerns/preference_token"

class PreferenceTokenTest < ActiveSupport::TestCase
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
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_not_nil token

      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal PreferenceToken::TOKEN_TYPE, header["typ"]

      decoded = PreferenceToken.decode(token, host: @host)

      assert_not_nil decoded
      assert_equal "dr", decoded.dig("preferences", "ct")
      assert_equal @jti, decoded["jti"]
      assert_equal PreferenceToken::TOKEN_TYPE, decoded["typ"]
    end
  end

  test "encodes and decodes with a sign surface issuer without using legacy preference issuer" do
    audiences = ["log.umaxica.app", "log.umaxica.com"].freeze
    PreferenceJwtConfiguration.stub(:audiences, audiences) do
      PreferenceJwtConfiguration.stub(:host_scope_for, "log.umaxica.app") do
        PreferenceJwtConfiguration.stub(:public_key_for, ->(_kid, issuer_id: "preference") { @public_key }) do
          token = PreferenceToken.encode(
            @prefs,
            host: "log.umaxica.app",
            preference_type: @preference_type,
            public_id: @public_id,
            jti: @jti,
            jwt_issuer_id: "surface:SIGN_APP",
          )

          assert_not_nil token

          decoded = PreferenceToken.decode(
            token,
            host: "log.umaxica.app",
            jwt_issuer_id: "surface:SIGN_APP",
          )

          assert_equal "dr", decoded.dig("preferences", "ct")
          assert_equal @jti, decoded["jti"]
        end
      end
    end
  end

  test "returns nil for invalid token" do
    with_jwt_keys do
      assert_nil PreferenceToken.decode("invalid", host: @host)
    end
  end

  test "returns nil for wrong host" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_nil PreferenceToken.decode(token, host: "wrong.com")
    end
  end

  test "returns nil for alg none token" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, nil, "none", { typ: PreferenceToken::TOKEN_TYPE })

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test "returns nil for unknown kid" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, @private_key, "ES384", header.merge("kid" => "unknown-kid"))

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test ".app token cannot be replayed against the .com surface" do
    audiences = ["log.umaxica.app", "log.umaxica.com"].freeze
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    PreferenceJwtConfiguration.stub(:private_key, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key, @public_key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, @issuer) do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
                  app_token = PreferenceToken.encode(
                    @prefs,
                    host: "log.umaxica.app",
                    preference_type: "AppPreference",
                    public_id: @public_id,
                    jti: @jti,
                  )

                  assert_not_nil app_token
                  assert_nil PreferenceToken.decode(app_token, host: "log.umaxica.com"),
                             "audience scoped to .app TLD must not validate on a .com host"
                end
              end
            end
          end
        end
      end
    end
  end

  test "JwtConfiguration.audiences derives host names from boot config" do
    expected = Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:host)
    expected.concat(%w(app.localhost org.localhost com.localhost localhost))
    expected.uniq!

    assert_equal expected, PreferenceJwtConfiguration.audiences
  end

  test "audience_for requires a host" do
    PreferenceJwtConfiguration.stub(:audiences, ["example.com"]) do
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for(nil) }
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for("") }
    end
  end

  private

  def with_jwt_keys
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    PreferenceJwtConfiguration.stub(:private_key, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key, @public_key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, @issuer) do
                PreferenceJwtConfiguration.stub(:audiences, @audiences) do
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
