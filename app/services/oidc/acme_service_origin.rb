# typed: false
# frozen_string_literal: true

module Oidc
  class AcmeServiceOrigin
    DEFAULT_HTTP_PORT = 80
    DEFAULT_HTTPS_PORT = 443

    Decision =
      Data.define(
        :kind,
        :reason_code,
        :same_site,
        :request_host,
        :request_scheme,
        :target_scheme,
        :target_host,
        :target_port,
        :target_path,
        :acme_scheme,
        :acme_host,
        :acme_port,
      ) do
        def direct?
          kind == :direct
        end

        def jump?
          kind == :jump
        end

        def rejected?
          kind == :rejected
        end
      end

    class << self
      def from(value, default_scheme:)
        raw = value.to_s.strip
        raise ArgumentError, "missing origin" if raw.blank?

        parsed = parse_origin(raw, default_scheme: default_scheme)
        new(
          scheme: parsed.scheme.to_s.downcase,
          host: parsed.host.to_s.downcase,
          port: normalize_port(parsed.scheme, parsed.port),
        )
      end

      def host_from(value)
        raw = value.to_s.strip
        return nil if raw.blank?

        parsed = parse_origin(raw, default_scheme: "https")
        parsed.host.to_s.downcase.presence
      rescue ArgumentError, URI::InvalidURIError
        nil
      end

      private

      def parse_origin(raw, default_scheme:)
        normalized = raw.match?(%r{\Ahttps?://}i) ? raw : "#{default_scheme}://#{raw}"
        uri = URI.parse(normalized)

        raise ArgumentError, "invalid origin" unless uri.is_a?(URI::HTTP)
        raise ArgumentError, "invalid origin" unless %w(http https).include?(uri.scheme)
        raise ArgumentError, "invalid origin" if uri.userinfo.present?
        raise ArgumentError, "invalid origin" if uri.host.blank?
        raise ArgumentError, "invalid origin" if uri.path.present? && uri.path != "/"
        raise ArgumentError, "invalid origin" if uri.query.present?
        raise ArgumentError, "invalid origin" if uri.fragment.present?

        uri
      rescue URI::InvalidURIError
        raise ArgumentError, "invalid origin"
      end

      def normalize_port(scheme, port)
        default_port = default_port_for(scheme)
        return nil if port.blank? || port == default_port

        port
      end

      def default_port_for(scheme)
        scheme.to_s.casecmp("https").zero? ? DEFAULT_HTTPS_PORT : DEFAULT_HTTP_PORT
      end
    end

    attr_reader :scheme, :host, :port

    def initialize(scheme:, host:, port:)
      @scheme = scheme.to_s.downcase
      @host = host.to_s.downcase
      @port = port
    end

    def origin
      build_uri("/").to_s.delete_suffix("/")
    end

    def authorization_endpoint(query: nil)
      uri = build_uri("/oauth/authorize")
      uri.query = query.to_query if query.present?
      uri.to_s
    end

    def token_endpoint
      build_uri("/oauth/token").to_s
    end

    def same_site_authorize_url?(url, request:)
      decision_for_authorize_url(url, request: request).direct?
    end

    def same_site_rejection_reason(url, request:)
      decision = decision_for_authorize_url(url, request: request)
      return nil if decision.direct?

      decision.reason_code
    end

    def decision_for_authorize_url(url, request:)
      target = parse_target_url(url)
      return reject_decision("invalid_url", request:, target: nil) if target.nil?
      return jump_decision("native_custom_scheme", request:, target:) unless http_or_https?(target)
      return jump_decision("not_acme_authorize", request:, target:) unless target.path == "/oauth/authorize"

      target_scheme = target.scheme.to_s.downcase
      target_host = target.host.to_s.downcase
      target_port = normalize_port(target_scheme, target.port)
      request_host = host_only(request)
      request_scheme = request.scheme.to_s.downcase
      same_site = same_site_host?(request_host, target_host)

      return jump_decision("scheme_mismatch", request:, target:, same_site:, target_scheme:, target_host:, target_port:) if target_scheme != scheme
      return jump_decision("host_mismatch", request:, target:, same_site:, target_scheme:, target_host:, target_port:) if target_host != host
      return jump_decision("port_mismatch", request:, target:, same_site:, target_scheme:, target_host:, target_port:) if target_port != port
      return jump_decision("site_mismatch", request:, target:, same_site:, target_scheme:, target_host:, target_port:) unless same_site

      Decision.new(
        kind: :direct,
        reason_code: "direct_same_site_acme_authorize",
        same_site: true,
        request_host: request_host,
        request_scheme: request_scheme,
        target_scheme: target_scheme,
        target_host: target_host,
        target_port: target_port,
        target_path: target.path,
        acme_scheme: scheme,
        acme_host: host,
        acme_port: port,
      )
    end

    private

    def build_uri(path)
      URI::Generic.build(
        scheme: scheme,
        host: host,
        port: port,
        path: path,
      )
    end

    def normalize_port(scheme, port)
      self.class.send(:normalize_port, scheme, port)
    end

    def parse_target_url(url)
      uri = URI.parse(url.to_s)
      return nil if uri.scheme.blank? && uri.host.blank?
      return nil if uri.scheme.blank? && uri.path.present? && !uri.path.start_with?("/")

      uri
    rescue URI::InvalidURIError
      nil
    end

    def http_or_https?(uri)
      %w(http https).include?(uri.scheme.to_s.downcase)
    end

    def same_site_host?(request_host, target_host)
      request_site_key(request_host) == request_site_key(target_host)
    end

    def request_site_key(host)
      normalized = host.to_s.downcase
      return if normalized.blank?

      labels = normalized.split(".")
      return normalized if labels.one?

      labels.last(2).join(".")
    end

    def host_only(request)
      request.host.to_s.downcase
    end

    def reject_decision(reason_code, request:, target:)
      Decision.new(
        kind: :rejected,
        reason_code: reason_code,
        same_site: false,
        request_host: host_only(request),
        request_scheme: request.scheme.to_s.downcase,
        target_scheme: target&.scheme&.to_s&.downcase,
        target_host: target&.host&.to_s&.downcase,
        target_port: target ? normalize_port(target.scheme, target.port) : nil,
        target_path: target&.path,
        acme_scheme: scheme,
        acme_host: host,
        acme_port: port,
      )
    end

    def jump_decision(reason_code, request:, target:, same_site: false, target_scheme: nil, target_host: nil,
                      target_port: nil)
      Decision.new(
        kind: :jump,
        reason_code: reason_code,
        same_site: same_site,
        request_host: host_only(request),
        request_scheme: request.scheme.to_s.downcase,
        target_scheme: target_scheme || target.scheme.to_s.downcase,
        target_host: target_host || target.host.to_s.downcase,
        target_port: target_port.nil? ? normalize_port(target.scheme, target.port) : target_port,
        target_path: target.path,
        acme_scheme: scheme,
        acme_host: host,
        acme_port: port,
      )
    end
  end
end
