# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class RedirectsController < Sign::RedirectOnlyController
        include ::SignPreferenceAuthorityRedirect

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
