# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderAvailabilityFactory
    def self.current
      FlipperProviderAvailabilityAdapter.new
    end
  end
end
