# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class ThemesController < PreferencesBaseController
        AUTHENTICATION_MODE = :open

        include ::Preference::SignScreenActions

        before_action :ensure_preferences_record

        def edit
          edit_theme_preference_screen
        end

        def update
          update_theme_preference_screen
        end
      end
    end
  end
end
