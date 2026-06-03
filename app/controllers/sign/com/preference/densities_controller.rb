# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class DensitiesController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
