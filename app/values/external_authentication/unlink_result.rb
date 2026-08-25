# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class UnlinkResult < Data.define(:status, :provider)
    STATUSES = %i(unlinked already_unlinked).freeze

    def initialize(status:, provider:)
      raise ArgumentError, "status is unsupported" unless STATUSES.include?(status)
      raise ArgumentError, "provider is unsupported" unless VerifiedPrincipal::PROVIDERS.include?(provider)

      super
    end

    def unlinked? = status == :unlinked

    def already_unlinked? = status == :already_unlinked
  end
end
