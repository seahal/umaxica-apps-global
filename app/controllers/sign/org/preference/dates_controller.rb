# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class DatesController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
