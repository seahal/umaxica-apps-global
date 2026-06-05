# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class RedirectsController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
