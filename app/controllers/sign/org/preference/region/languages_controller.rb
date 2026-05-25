# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      module Region
        class LanguagesController < PreferencesBaseController
          AUTHENTICATION_MODE = :open

          include ::Preference::SignScreenActions

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
