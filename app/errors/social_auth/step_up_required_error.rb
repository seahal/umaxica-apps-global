# typed: false
# frozen_string_literal: true

module SocialAuth
  # Raised when a sensitive operation requires recent step-up authentication
  # but the current session token's step-up state is too old or missing.
  # Maps to HTTP 403 Forbidden (not 401 to avoid triggering browser auth dialogs)
  class StepUpRequiredError < BaseError
    def initialize(i18n_key = "errors.social_auth.step_up_required", **context)
      super(i18n_key, :forbidden, **context)
    end
  end
end
