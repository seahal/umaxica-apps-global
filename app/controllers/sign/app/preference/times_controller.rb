# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class TimesController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
