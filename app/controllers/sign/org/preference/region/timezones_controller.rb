# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      module Region
        class TimezonesController < PreferencesBaseController
          include ::Preference::SignScreenActions

          before_action :ensure_preferences_record

          def edit
            edit_timezone_preference_screen
          end

          def update
            update_timezone_preference_screen
          end
        end
      end
    end
  end
end
