# typed: false
# frozen_string_literal: true

module Webauthn
  # Immutable relying-party configuration for one WebAuthn surface.
  #
  # Invariants enforced here (see docs/security/webauthn-security-invariants.md):
  # - the origin is an absolute http(s) origin without path/query/fragment
  # - the RP ID equals the origin host exactly — parent-domain RP IDs are
  #   forbidden so credentials can never be shared across surfaces
  # - origin comparison is exact on scheme, host, and effective port
  class RelyingPartyConfig
    class InvalidConfigError < StandardError; end

    RP_NAME = "Umaxica"

    attr_reader :rp_id, :origin

    def initialize(rp_id:, origin:)
      @rp_id = rp_id.to_s
      @origin = origin.to_s
      validate!
      @origin_uri = parse_origin(@origin)
    end

    # Exact-match origin check: scheme, host, and effective port must all be
    # equal. Default ports (443/80) compare equal to their explicit forms.
    def trusted_origin?(candidate)
      candidate_uri = parse_origin(candidate.to_s)

      candidate_uri.scheme == origin_uri.scheme &&
        candidate_uri.host == origin_uri.host &&
        candidate_uri.port == origin_uri.port
    rescue InvalidConfigError
      false
    end

    def relying_party
      @relying_party ||= WebAuthn::RelyingParty.new(
        id: rp_id,
        name: RP_NAME,
        allowed_origins: [origin],
        encoding: :base64url,
        credential_options_timeout: 120_000,
      )
    end

    def ==(other)
      other.is_a?(RelyingPartyConfig) && other.rp_id == rp_id && other.origin == origin
    end
    alias eql? ==

    def hash = [self.class, rp_id, origin].hash

    private

    attr_reader :origin_uri

    def validate!
      raise InvalidConfigError, "rp_id must be present" if rp_id.blank?

      uri = parse_origin(origin)

      return if uri.host == rp_id

      raise InvalidConfigError,
            "rp_id (#{rp_id}) must equal the origin host (#{uri.host}); " \
            "parent-domain RP IDs would allow cross-surface credential reuse"

    end

    def parse_origin(value)
      uri = URI.parse(value)

      unless uri.is_a?(URI::HTTP) && uri.host.present?
        raise InvalidConfigError, "origin must be an absolute http(s) origin: #{value.inspect}"
      end
      if uri.path.present? || uri.query.present? || uri.fragment.present?
        raise InvalidConfigError, "origin must not contain path, query, or fragment: #{value.inspect}"
      end

      uri
    rescue URI::InvalidURIError
      raise InvalidConfigError, "origin is not a valid URI: #{value.inspect}"
    end
  end
end
