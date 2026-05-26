# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      module Region
        class LanguagesController < PreferencesBaseController
          include ::Preference::SignScreenActions

          AUTHENTICATION_MODE = :open

          before_action :ensure_preferences_record

          def edit
            edit_language_preference_screen
          end

          def update
            update_language_preference_screen
          end
        end
      end
    end
  end
end
