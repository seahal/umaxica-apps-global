# typed: false
# frozen_string_literal: true

module Redirects
  class ExternalTargetResolver
    DANGEROUS_QUERY_KEYS = %w[redirect_uri return_to rt pt nt xt redirect_to next continue url].freeze

    REGISTRY = {
      rp_app: { env: "RP_APP_URL", default: "https://rp.app.localhost" },
      idp: { env: "ID_CORPORATE_URL", default: "https://id.com.localhost" },
      jump: { env: "JUMP_CORPORATE_URL", default: "https://jump.com.localhost" },
    }.freeze

    def self.call(key, path: "/", query: {}, source: :explicit_xt)
      new(key, path: path, query: query, source: source).call
    end

    def self.url(value, allowed_urls:, source: :explicit_xt_url)
      uri = URI.parse(value.to_s)
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :invalid_uri, unsafe_value: value) if uri.host.blank?
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :userinfo, unsafe_value: value) if uri.userinfo.present?
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :fragment, unsafe_value: value) if uri.fragment.present?
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :control_char, unsafe_value: value) if value.to_s.match?(/[\x00-\x1F\x7F]/)
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :https_required, unsafe_value: value) unless uri.scheme == "https" || local_uri_allowed?(uri)

      allowed = Array(allowed_urls).map { |url| normalized_origin(url) }.compact
      origin = normalized_origin(uri.to_s)
      return Redirects::TargetResult.failure(kind: :xt, source: source, reason: :origin_denied, unsafe_value: value) unless allowed.include?(origin)

      Redirects::TargetResult.ok(kind: :xt, source: source, value: uri.to_s)
    rescue URI::InvalidURIError
      Redirects::TargetResult.failure(kind: :xt, source: source, reason: :invalid_uri, unsafe_value: value)
    end

    def initialize(key, path:, query:, source:)
      @key = key
      @path = path
      @query = query.to_h
      @source = source
    end

    def call
      registry_key = normalize_key
      return failure(:unknown_key) unless REGISTRY.key?(registry_key)

      origin = origin_for(REGISTRY.fetch(registry_key))
      return failure(:invalid_origin) if origin.blank?

      uri = URI.parse(origin)
      return failure(:https_required) unless uri.scheme == "https" || local_origin_allowed?(uri)
      return failure(:missing_host) if uri.host.blank?

      safe_path = Redirects::PathTargetResolver.call(path.to_s, source: source)
      return failure(:invalid_path) unless safe_path.ok?

      uri.path = safe_path.value.split("?").first
      uri.query = merged_query(safe_path.value, query)
      uri.fragment = nil
      uri.user = nil
      uri.password = nil

      Redirects::TargetResult.ok(kind: :xt, source: source, value: uri.to_s)
    rescue URI::InvalidURIError
      failure(:invalid_uri)
    end

    private

    attr_reader :key, :path, :query, :source

    def normalize_key
      return key if key.is_a?(Symbol)
      return key.to_sym if key.is_a?(String) && key.match?(/\A[a-z][a-z0-9_]*\z/)
    end

    def origin_for(entry)
      ENV.fetch(entry.fetch(:env), entry.fetch(:default)).presence
    end

    def local_origin_allowed?(uri)
      self.class.local_uri_allowed?(uri)
    end

    def self.local_uri_allowed?(uri)
      return false unless Rails.env.development? || Rails.env.test?
      return false unless uri.scheme == "http"

      uri.host.to_s.end_with?(".localhost") || %w[localhost 127.0.0.1 ::1].include?(uri.host)
    end

    def self.normalized_origin(value)
      uri = URI.parse(value.to_s)
      return if uri.scheme.blank? || uri.host.blank?

      port = uri.port
      default_port = uri.scheme == "https" ? 443 : 80
      host = uri.host.downcase
      port.present? && port != default_port ? "#{uri.scheme}://#{host}:#{port}" : "#{uri.scheme}://#{host}"
    rescue URI::InvalidURIError
      nil
    end

    def merged_query(path_value, raw_query)
      path_query = URI.parse(path_value).query
      pairs = URI.decode_www_form(path_query.to_s).reject { |key, _value| DANGEROUS_QUERY_KEYS.include?(key) }
      safe_query = raw_query.stringify_keys.except(*DANGEROUS_QUERY_KEYS)
      pairs.concat(safe_query.to_a)
      pairs.present? ? URI.encode_www_form(pairs) : nil
    end

    def failure(reason)
      Redirects::TargetResult.failure(kind: :xt, source: source, reason: reason, unsafe_value: key)
    end
  end
end
