# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class LegacyIdentityCredentialAttributes
    NOT_STORED = "[NOT_STORED]".freeze

    def initialize(provider:, credential_candidate:)
      @provider = provider.to_s
      @credential_candidate = credential_candidate
      validate!
    end

    def to_h
      case provider
      when "apple"
        {
          token: NOT_STORED,
          refresh_token: credential_candidate.refresh_token,
          token_expires_at: 0,
        }
      when "google"
        {
          token: NOT_STORED,
          refresh_token: "",
          token_expires_at: 0,
        }
      else
        raise ArgumentError, "provider is unsupported"
      end
    end

    private

    attr_reader :provider, :credential_candidate

    def validate!
      case provider
      when "apple"
        return if credential_candidate.is_a?(AppleCredentialCandidate)

        raise ArgumentError, "Apple credential candidate is required"
      when "google"
        return if credential_candidate.nil?

        raise ArgumentError, "Google credential candidate must be absent"
      else
        raise ArgumentError, "provider is unsupported"
      end
    end
  end
end
