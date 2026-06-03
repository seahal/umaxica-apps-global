# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class LanguagesController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
