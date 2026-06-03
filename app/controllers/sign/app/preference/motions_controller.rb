# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class MotionsController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
