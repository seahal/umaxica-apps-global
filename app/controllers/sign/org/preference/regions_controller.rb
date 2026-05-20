# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class RegionsController < PreferencesBaseController
        include ::Preference::SignScreenActions

        preference_screen :region
      end
    end
  end
end
