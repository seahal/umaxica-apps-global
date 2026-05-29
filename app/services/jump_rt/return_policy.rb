# typed: false
# frozen_string_literal: true

module JumpRt
  module ReturnPolicy
    module_function

    ALLOWED_SOURCES = {
      "https://www.umaxica.app" => %w(https://id.umaxica.app https://www.umaxica.app),
      "https://www.umaxica.com" => %w(https://id.umaxica.com https://www.umaxica.com),
      "https://www.umaxica.org" => %w(https://id.umaxica.org https://www.umaxica.org),
      "https://www.jp.umaxica.app" => %w(https://www.jp.umaxica.app),
      "https://www.jp.umaxica.com" => %w(https://www.jp.umaxica.com),
      "https://www.jp.umaxica.org" => %w(https://www.jp.umaxica.org),
    }.freeze

    def allowed_source?(destination_origin:, source:)
      sources = allowed_sources.fetch(normalize_origin(destination_origin), [])
      sources.include?(normalize_origin(source))
    end

    def allowed_sources
      ALLOWED_SOURCES.merge(env_allowed_sources) do |_origin, left, right|
        (left + right).uniq
      end
    end

    def normalize_origin(value)
      uri = URI.parse(value.to_s)
      return nil unless uri.is_a?(URI::HTTP)
      return nil unless %w(http https).include?(uri.scheme)
      return nil if uri.host.blank?
      return nil if uri.userinfo.present?

      port = (uri.port && uri.port != default_port_for(uri.scheme)) ? ":#{uri.port}" : ""
      "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}"
    rescue URI::InvalidURIError
      nil
    end

    def default_port_for(scheme)
      scheme.to_s.casecmp("https").zero? ? 443 : 80
    end

    def env_allowed_sources
      {
        env_origin("ACME_SERVICE_URL", "www.app.localhost") => env_sources(
          destination_env: "ACME_SERVICE_URL",
          destination_default: "www.app.localhost",
          issuer_env: "ID_SERVICE_URL",
          issuer_default: "id.app.localhost",
        ),
        env_origin("ACME_CORPORATE_URL", "www.com.localhost") => env_sources(
          destination_env: "ACME_CORPORATE_URL",
          destination_default: "www.com.localhost",
          issuer_env: "ID_CORPORATE_URL",
          issuer_default: "id.com.localhost",
        ),
        env_origin("ACME_STAFF_URL", "www.org.localhost") => env_sources(
          destination_env: "ACME_STAFF_URL",
          destination_default: "www.org.localhost",
          issuer_env: "ID_STAFF_URL",
          issuer_default: "id.org.localhost",
        ),
        env_origin("CORE_SERVICE_URL", "www.jp.umaxica.app") => env_sources(
          destination_env: "CORE_SERVICE_URL",
          destination_default: "www.jp.umaxica.app",
          issuer_env: "CORE_SERVICE_URL",
          issuer_default: "www.jp.umaxica.app",
        ),
        env_origin("CORE_CORPORATE_URL", "www.jp.umaxica.com") => env_sources(
          destination_env: "CORE_CORPORATE_URL",
          destination_default: "www.jp.umaxica.com",
          issuer_env: "CORE_CORPORATE_URL",
          issuer_default: "www.jp.umaxica.com",
        ),
        env_origin("CORE_STAFF_URL", "www.jp.umaxica.org") => env_sources(
          destination_env: "CORE_STAFF_URL",
          destination_default: "www.jp.umaxica.org",
          issuer_env: "CORE_STAFF_URL",
          issuer_default: "www.jp.umaxica.org",
        ),
      }.compact
    end

    def env_sources(destination_env:, destination_default:, issuer_env:, issuer_default:)
      [
        env_origin(issuer_env, issuer_default),
        env_origin(destination_env, destination_default),
      result = [].compact
      result.uniq!
      result
    end

    def env_origin(key, fallback)
      value = ENV.fetch(key, fallback)
      raw = value.to_s.match?(%r{\Ahttps?://}) ? value : "https://#{value}"
      normalize_origin(raw)
    end
  end
end
