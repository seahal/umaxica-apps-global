# typed: false
# frozen_string_literal: true

require "json/jwt"

module ExternalAuthentication
  class AppleClientSecretProvider
    include AppleClientSecretProviderPort

    ISSUER = "https://appleid.apple.com"
    DEFAULT_TTL = 5.minutes
    MAXIMUM_TTL = 180.days

    def self.from_credentials
      new(
        client_id: Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID),
        team_id: Rails.app.creds.option(:OMNI_AUTH_APPLE_TEAM_ID),
        key_id: Rails.app.creds.option(:OMNI_AUTH_APPLE_KEY_ID),
        private_key_pem: Rails.app.creds.option(:OMNI_AUTH_APPLE_PRIVATE_KEY),
      )
    end

    def initialize(client_id:, team_id:, key_id:, private_key_pem:, clock: -> { Time.current }, ttl: DEFAULT_TTL)
      @client_id = required_string(client_id, "client_id")
      @team_id = required_string(team_id, "team_id")
      @key_id = required_string(key_id, "key_id")
      @private_key = OpenSSL::PKey::EC.new(required_string(private_key_pem, "private_key_pem"))
      @clock = clock
      @ttl = validate_ttl(ttl)
    end

    def call
      now = clock.call
      jwt = JSON::JWT.new(
        iss: team_id,
        aud: ISSUER,
        sub: client_id,
        iat: now.to_i,
        exp: (now + ttl).to_i,
      )
      jwt.kid = key_id
      jwt.sign(private_key).to_s
    end

    def private_key_configured?
      private_key.private?
    end

    private

    attr_reader :client_id, :team_id, :key_id, :private_key, :clock, :ttl

    def required_string(value, name)
      return value if value.is_a?(String) && value.present?

      raise ArgumentError, "#{name} is required"
    end

    def validate_ttl(value)
      raise ArgumentError, "ttl must be positive" unless value.respond_to?(:positive?) && value.positive?
      raise ArgumentError, "ttl must not exceed 180 days" if value > MAXIMUM_TTL

      value
    end
  end
end
