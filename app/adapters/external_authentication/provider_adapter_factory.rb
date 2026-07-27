# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderAdapterFactory
    def self.build(provider:, audience: nil, connection: nil, redirect_uri: nil)
      entry = ProviderRegistry.fetch(provider)

      case entry.adapter_key
      when :apple_oidc
        AppleProviderAdapter.new(audience: audience)
      when :google_oidc
        GoogleProviderAdapter.new(audience: audience)
      when :entra_oidc
        raise ArgumentError, "connection is required" if connection.nil?
        raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?

        EntraProviderAdapter.new(connection: connection, redirect_uri: redirect_uri)
      else
        raise ArgumentError, "adapter is unsupported"
      end
    end
  end
end
