# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class AppleProviderAdapter
    PROVIDER = "apple"
    VERIFICATION_AUTHORITY =
      "omniauth-apple/#{Gem.loaded_specs.fetch("omniauth-apple").version}".freeze

    def initialize(audience:)
      raise ArgumentError, "audience is required" unless audience.is_a?(String) && audience.present?

      @audience = audience.dup.freeze
    end

    def call(auth_hash:, verified_at:)
      return failed(code: :invalid_callback, safe_reason: :callback_invalid) unless auth_hash.is_a?(OmniAuth::AuthHash)
      return failed(code: :invalid_callback, safe_reason: :provider_mismatch) unless auth_hash.provider == PROVIDER
      return failed(code: :verification_failed, safe_reason: :assertion_invalid) unless auth_hash.uid.is_a?(String) && auth_hash.uid.present?

      CallbackResult.verified(
        principal: VerifiedPrincipal.new(
          provider: PROVIDER,
          subject: auth_hash.uid,
          issuer: ProviderRegistry.fetch(PROVIDER).issuer,
          audience: @audience,
          verified_at: verified_at,
          verification_authority: VERIFICATION_AUTHORITY,
        ),
        credential_candidate: nil,
      )
    end

    private

    def failed(code:, safe_reason:)
      CallbackResult.failed(
        failure: Failure.new(
          code: code,
          provider: PROVIDER,
          retryable: false,
          safe_reason: safe_reason,
        ),
      )
    end
  end
end
