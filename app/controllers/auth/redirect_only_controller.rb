# typed: false
# frozen_string_literal: true

# FIXME: I want to delete this file.
module Auth
  class RedirectOnlyController < ApplicationController
    include ::SignAcmeAuthorityRedirect

    AUTHENTICATION_MODE = :open

    protect_from_forgery with: :exception

    private

    # auth/id is redirect-only here; base/www owns authority mutation.
  end
end
