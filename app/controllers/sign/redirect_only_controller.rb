# typed: false
# frozen_string_literal: true

# FIXME: I want to delete this file.
module Sign
  class RedirectOnlyController < ApplicationController
    include ::Sign::AcmeAuthorityRedirect

    AUTHENTICATION_MODE = :open

    protect_from_forgery with: :exception

    private

    # sign/id is redirect-only here; acme/www owns authority mutation.
  end
end
