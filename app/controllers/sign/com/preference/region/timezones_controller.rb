# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      module Region
        class TimezonesController < PreferencesBaseController
          include ::Preference::SignScreenActions

          preference_screen :timezone
        end
      end
    end
  end
end
