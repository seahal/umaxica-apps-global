# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderAdapterFactory
    # Entra ID is not built by this factory: it is a Umaxica-specific
    # OmniAuth strategy (lib/omniauth/strategies/umaxica_entra.rb) that owns
    # its own token exchange directly, not through an
    # ExternalAuthentication::*ProviderAdapter. See
    # adr/org-entra-omniauth-strategy-migration.md.
    def self.build(provider:, audience: nil)
      entry = ProviderRegistry.fetch(provider)

      case entry.adapter_key
      when :apple_oidc
        AppleProviderAdapter.new(audience: audience)
      when :google_oidc
        GoogleProviderAdapter.new(audience: audience)
      else
        raise ArgumentError, "adapter is unsupported"
      end
    end
  end
end
