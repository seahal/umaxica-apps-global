# typed: false
# frozen_string_literal: true

# FIXME: I want to delete this file.
module Auth
  class RedirectOnlyController < ApplicationController
    include ::SignAcmeAuthorityRedirect

    AUTHENTICATION_MODE = :open

    # `using:` must be stated explicitly. Omitting it falls back to
    # config.load_defaults(8.2), which sets forgery_protection_verification_strategy
    # to :header_only - stricter than every other surface here, and it rejects
    # browsers that do not send Sec-Fetch-Site, which is exactly the case
    # :header_or_legacy_token exists to cover.
    protect_from_forgery using: :header_or_legacy_token, with: :exception

    private

    # auth/id is redirect-only here; base/www owns authority mutation.
  end
end
