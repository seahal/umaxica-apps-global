# typed: false
# frozen_string_literal: true

require "jwt"

module ExternalAuthentication
  class AppleNotificationVerifier
    include AppleNotificationVerifierPort

    ISSUER = "https://appleid.apple.com"
    ALGORITHM = "RS256"
    MAXIMUM_AGE = 24.hours
    MAXIMUM_CLOCK_SKEW = 5.minutes

    class VerificationError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    class ConfigurationError < StandardError; end

    def self.from_credentials(jws:)
      audience = Rails.app.creds.option(:OMNI_AUTH_APPLE_NOTIFICATION_AUDIENCE)
      raise ConfigurationError, "Apple notification audience is required" unless audience.is_a?(String) && audience.present?

      new(
        jws: jws,
        audience: audience,
        jwks_loader: AppleNotificationJwksCache.new.loader,
      )
    end

    def initialize(jws:, audience:, jwks_loader:, clock: -> { Time.current })
      @jws = required_string(jws, :jws)
      @audience = required_string(audience, :audience)
      raise ArgumentError, "jwks_loader must respond to call" unless jwks_loader.respond_to?(:call)

      @jwks_loader = jwks_loader
      @clock = clock
    end

    def call
      validate_header!
      payload = decode_payload
      issued_at = required_time(payload["iat"], :issued_at)
      validate_freshness!(issued_at)
      events = required_events(payload["events"])

      VerifiedAppleNotification.new(
        jti: required_string(payload["jti"], :jti_missing),
        event_type: required_event_type(events["type"]),
        subject: required_string(events["sub"], :subject_missing),
        issued_at: issued_at,
        occurred_at: required_time(events["event_time"], :event_time_missing),
      )
    rescue VerificationError
      raise
    rescue JWT::DecodeError, JWT::VerificationError, JWT::JWKError, OpenSSL::PKey::PKeyError,
           ArgumentError, KeyError, TypeError
      raise VerificationError.new(:signature_or_claims_invalid)
    end

    private

    attr_reader :jws, :audience, :jwks_loader, :clock

    def validate_header!
      _payload, header = JWT.decode(jws, nil, false)
      raise VerificationError.new(:algorithm_invalid) unless header["alg"] == ALGORITHM
      raise VerificationError.new(:kid_missing) if header["kid"].to_s.blank?
    rescue JWT::DecodeError
      raise VerificationError.new(:malformed_jws)
    end

    def decode_payload
      JWT.decode(
        jws,
        nil,
        true,
        algorithms: [ALGORITHM],
        jwks: jwks_loader,
        iss: ISSUER,
        verify_iss: true,
        aud: audience,
        verify_aud: true,
        verify_expiration: false,
      ).first
    end

    def validate_freshness!(issued_at)
      now = clock.call
      raise VerificationError.new(:issued_at_future) if issued_at > now + MAXIMUM_CLOCK_SKEW
      raise VerificationError.new(:issued_at_expired) if issued_at < now - MAXIMUM_AGE
    end

    def required_events(value)
      return value if value.is_a?(Hash)

      raise VerificationError.new(:events_invalid)
    end

    def required_event_type(value)
      return value if VerifiedAppleNotification::EVENT_TYPES.include?(value)

      raise VerificationError.new(:event_type_invalid)
    end

    def required_time(value, code)
      return Time.at(value).utc if value.is_a?(Integer) && value.positive?

      raise VerificationError.new(code)
    end

    def required_string(value, code)
      return value if value.is_a?(String) && value.present?

      raise VerificationError.new(code)
    end
  end
end
