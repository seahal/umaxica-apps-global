# typed: false
# frozen_string_literal: true

require "openssl"

module PreferenceJwtHelper
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1")

  # PreferenceJwtConfiguration is defined alongside PreferenceBase.
  _ = PreferenceBase

  # Encode a real preference JWT token for use in controller tests.
  # This uses actual PreferenceToken.encode with stubbed keys, producing
  # a token that passes full JWT verification (signature, claims, host).
  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = "test-jti-#{SecureRandom.uuid}"
    token = nil

    with_preference_jwt_keys(host: host) do
      token = PreferenceToken.encode(
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
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences

    pub_key_for_stub = ->(_kid, **_options) { PREFERENCE_JWT_KEY }

    PreferenceJwtConfiguration.stub(:private_key, PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
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
