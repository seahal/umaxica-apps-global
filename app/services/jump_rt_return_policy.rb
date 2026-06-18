# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  ALLOWED_SOURCES = {
    "https://www.umaxica.app" => %w(https://id.umaxica.app https://www.umaxica.app),
    "https://www.umaxica.com" => %w(https://id.umaxica.com https://www.umaxica.com),
    "https://www.umaxica.org" => %w(https://id.umaxica.org https://www.umaxica.org),
    "https://www-jp.umaxica.app" => %w(https://www-jp.umaxica.app),
    "https://www-jp.umaxica.com" => %w(https://www-jp.umaxica.com),
    "https://www-jp.umaxica.org" => %w(https://www-jp.umaxica.org),
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
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    {
      normalize_origin(hosts.acme_service.to_s) => env_sources(
        destination_host: hosts.acme_service.to_s,
        issuer_host: hosts.sign_service.to_s,
      ),
      normalize_origin(hosts.acme_corporate.to_s) => env_sources(
        destination_host: hosts.acme_corporate.to_s,
        issuer_host: hosts.sign_corporate.to_s,
      ),
      normalize_origin(hosts.acme_staff.to_s) => env_sources(
        destination_host: hosts.acme_staff.to_s,
        issuer_host: hosts.sign_staff.to_s,
      ),
      normalize_origin(hosts.core_service.to_s) => env_sources(
        destination_host: hosts.core_service.to_s,
        issuer_host: hosts.sign_service.to_s,
      ),
      normalize_origin(hosts.core_corporate.to_s) => env_sources(
        destination_host: hosts.core_corporate.to_s,
        issuer_host: hosts.sign_corporate.to_s,
      ),
      normalize_origin(hosts.core_staff.to_s) => env_sources(
        destination_host: hosts.core_staff.to_s,
        issuer_host: hosts.sign_staff.to_s,
      ),
    }.compact
  end

  def env_sources(destination_host:, issuer_host:)
    sources = [normalize_origin("https://#{issuer_host}"), normalize_origin("https://#{destination_host}")]
    sources.compact!
    sources.uniq!
    sources
  end
end
