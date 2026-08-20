# typed: false
# frozen_string_literal: true

module SocialAuth
  # Raised when trying to unlink the user's last authentication method
  # Maps to HTTP 422 Unprocessable Entity
  class LastIdentityError < BaseError
    def initialize(i18n_key = "errors.social_auth.last_identity", **context)
      super(i18n_key, :unprocessable_content, **context)
    end
  end
end
