# typed: false
# frozen_string_literal: true

require "jwt"

module JumpRt
  class Issuer
    ALGORITHM = "ES384"
    AUDIENCE_ENV = "JUMP_GATEWAY_URL"
    TTL_ENV = "JUMP_RT_TTL_SECONDS"
    DEFAULT_AUDIENCE = "https://jump.umaxica.net"
    DEFAULT_TTL = 5.minutes
    MAX_TTL = 5.minutes
    TOKEN_SUBJECT = "jump-redirect"
    VALID_DESTINATIONS = %w(internal external).freeze
    VALID_REPLAY_POLICIES = %w(reuse once).freeze
    # Defense in depth: strip redirect-target query keys from the signed URL so
    # the gateway cannot return a request that re-enters a `pt`/`nt`/`xt`/`rt`
    # processing path. Same list as Redirects::ExternalTargetResolver.
    DANGEROUS_QUERY_KEYS = %w(redirect_uri return_to rt pt nt xt redirect_to next continue url).freeze

    def self.call(...)
      new(...).call
    end

    def initialize(namespace:, url:, dst: "internal", replay_policy: "reuse", ttl: nil, now: Time.current,
                   jti: SecureRandom.uuid)
      @namespace = JumpRt::Surface.normalize_namespace(namespace)
      @url = url
      @dst = dst.to_s
      @replay_policy = replay_policy.to_s
      @ttl = ttl || default_ttl
      @now = now
      @jti = jti
    end

    def call
      return nil unless valid_destination?
      return nil unless valid_replay_policy?
      return nil unless valid_ttl?

      normalized_url = normalize_url(url)
      return nil if normalized_url.blank?

      kid = JumpRt::Keyring.active_kid(namespace)
      private_key = JumpRt::Keyring.private_key(namespace)
      return nil if kid.blank? || private_key.blank?

      JWT.encode(
        payload(normalized_url),
        private_key,
        ALGORITHM,
        { typ: "JWT", kid: kid },
      )
    end

    private

    attr_reader :namespace, :url, :dst, :replay_policy, :ttl, :now, :jti

    def payload(normalized_url)
      issued_at = now.to_i
      {
        schema: 1,
        iss: JumpRt::Surface.issuer_origin(namespace),
        aud: jump_audience,
        sub: TOKEN_SUBJECT,
        iat: issued_at,
        nbf: issued_at,
        exp: issued_at + ttl.to_i,
        jti: jti,
        dst: dst,
        rpl: replay_policy,
        url: normalized_url,
      }
    end

    def normalize_url(value)
      raw = value.to_s
      return nil if raw.blank?
      return nil if raw.match?(/[\x00-\x1F\x7F]/)

      uri = URI.parse(raw)
      return nil unless uri.is_a?(URI::HTTP)
      return nil unless uri.scheme == "https" || local_http_allowed?(uri)
      return nil if uri.host.blank?
      return nil if uri.userinfo.present?
      return nil if uri.fragment.present?

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.blank?
      uri.query = strip_dangerous_query(uri.query)
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def strip_dangerous_query(raw_query)
      return nil if raw_query.blank?

      pairs =
        Rack::Utils.parse_nested_query(raw_query).except(*DANGEROUS_QUERY_KEYS)
      pairs.present? ? Rack::Utils.build_nested_query(pairs) : nil
    end

    def valid_destination?
      VALID_DESTINATIONS.include?(dst)
    end

    def valid_replay_policy?
      VALID_REPLAY_POLICIES.include?(replay_policy)
    end

    def valid_ttl?
      ttl.to_i.positive? && ttl.to_i <= MAX_TTL.to_i
    end

    def default_ttl
      ENV.fetch(TTL_ENV, DEFAULT_TTL.to_i).to_i.seconds
    end

    def jump_audience
      ENV.fetch(AUDIENCE_ENV, DEFAULT_AUDIENCE).presence || DEFAULT_AUDIENCE
    end

    def local_http_allowed?(uri)
      return false unless Rails.env.local?

      uri.scheme == "http" && (uri.host == "localhost" || uri.host.end_with?(".localhost"))
    end
  end
end
