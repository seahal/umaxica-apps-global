# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class RedirectsController < Sign::RedirectOnlyController
        AUTHENTICATION_MODE = :open
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
