# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class Failure < Data.define(:code, :provider, :retryable, :safe_reason)
    CODES = %i(
      configuration_error
      invalid_callback
      provider_cancelled
      provider_unavailable
      replayed_callback
      verification_failed
      token_exchange_failed
      tenant_not_allowed
      tenant_mismatch
      identity_not_found
      not_authorized
    ).freeze

    SAFE_REASONS = %i(
      assertion_invalid
      callback_invalid
      callback_replayed
      ceremony_expired
      configuration_invalid
      provider_cancelled
      provider_mismatch
      provider_unavailable
      token_exchange_failed
      tenant_not_allowed
      tenant_mismatch
      identity_not_found
      not_authorized
    ).freeze

    PROVIDERS = %w(apple google entra).freeze

    def initialize(code:, provider:, retryable:, safe_reason:)
      raise ArgumentError, "code is unsupported" unless CODES.include?(code)
      raise ArgumentError, "provider is unsupported" unless PROVIDERS.include?(provider)
      unless retryable.equal?(true) || retryable.equal?(false)
        raise ArgumentError, "retryable must be boolean"
      end
      raise ArgumentError, "safe_reason is unsupported" unless SAFE_REASONS.include?(safe_reason)

      super(
        code: code,
        provider: provider.dup.freeze,
        retryable: retryable,
        safe_reason: safe_reason,
      )
    end
  end
end
