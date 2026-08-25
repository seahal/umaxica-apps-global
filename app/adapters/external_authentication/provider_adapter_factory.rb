# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderAdapterFactory
    # Entra ID's OmniAuth strategy (lib/omniauth/strategies/umaxica_entra.rb)
    # still owns token exchange and claim verification directly; the adapter
    # built here only normalizes the strategy's already-verified AuthHash into
    # the same CallbackResult shape Apple and Google produce.
    def self.build(provider:, audience: nil)
      entry = ProviderRegistry.fetch(provider)

      case entry.adapter_key
      when :apple_oidc
        AppleProviderAdapter.new(audience: audience)
      when :google_oidc
        GoogleProviderAdapter.new(audience: audience)
      when :entra_oidc
        EntraProviderAdapter.new(audience: audience)
      else
        raise ArgumentError, "adapter is unsupported"
      end
    end
  end
end
