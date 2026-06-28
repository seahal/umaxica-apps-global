# typed: false
# frozen_string_literal: true

require "openssl"

module PreferenceJwtHelper
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1")

  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    with_preference_jwt_keys(host: host) do
      PreferenceToken.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: "test-jti-#{SecureRandom.uuid}",
      )
    end
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    public_key_for_stub = ->(_kid, **_options) { PREFERENCE_JWT_KEY }

    PreferenceJwtConfiguration.stub(:private_key, PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, public_key_for_stub) do
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
