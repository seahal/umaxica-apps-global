# typed: false
# frozen_string_literal: true

module SocialAuth
  # Raised when there's an issue with the OAuth provider
  # - Unknown provider
  # - Provider returned error
  # Maps to HTTP 400 Bad Request or 502 Bad Gateway
  class SocialAuth::ProviderError < BaseError
    def initialize(i18n_key = "errors.social_auth.provider_error", **context)
      super(i18n_key, :bad_request, **context)
    end
  end
end
