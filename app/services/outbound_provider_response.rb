# typed: false
# frozen_string_literal: true

OutboundProviderResponse =
  Data.define(:provider, :provider_reference, :accepted_at) do
    def self.accepted(provider:, provider_reference:, accepted_at: Time.current)
      new(
        provider: provider.to_s,
        provider_reference: provider_reference.to_s,
        accepted_at: accepted_at,
      )
    end
  end
