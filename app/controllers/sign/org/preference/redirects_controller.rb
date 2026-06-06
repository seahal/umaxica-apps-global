# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class RedirectsController < ::Sign::RedirectOnlyController
        include ::SignPreferenceAuthorityRedirect

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
