# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class TimezonesController < Sign::RedirectOnlyController
        include ::Sign::PreferenceAuthorityRedirect
      end
    end
  end
end
