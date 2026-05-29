# typed: false
# frozen_string_literal: true

require "openssl"

module PreferenceJwtHelper
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1")

  # Preference::JwtConfiguration is defined alongside Preference::Base.
  _ = Preference::Base

  # Encode a real preference JWT token for use in controller tests.
  # This uses actual Preference::Token.encode with stubbed keys, producing
  # a token that passes full JWT verification (signature, claims, host).
  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = "test-jti-#{SecureRandom.uuid}"
    token = nil

    with_preference_jwt_keys(host: host) do
      token = Preference::Token.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
      )
    end

    token
  end

  # Wraps a block with stubbed JWT keys so that both encode and decode work.
  # Use this around HTTP requests in integration tests so the controller can
  # decode the token we encoded.
  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : Preference::JwtConfiguration.audiences

    pub_key_for_stub = ->(_kid, **_options) { PREFERENCE_JWT_KEY }

    Preference::JwtConfiguration.stub(:private_key, PREFERENCE_JWT_KEY) do
      Preference::JwtConfiguration.stub(:public_key, PREFERENCE_JWT_KEY) do
        Preference::JwtConfiguration.stub(:private_key_for_active, PREFERENCE_JWT_KEY) do
          Preference::JwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            Preference::JwtConfiguration.stub(:active_kid, "default") do
              Preference::JwtConfiguration.stub(:issuer, "jit-preference") do
                Preference::JwtConfiguration.stub(:audiences, audiences) do
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
