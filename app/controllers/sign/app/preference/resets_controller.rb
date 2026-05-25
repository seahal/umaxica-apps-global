# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class ResetsController < PreferencesBaseController
        AUTHENTICATION_MODE = :open

        include ::Preference::SignScreenActions

        before_action :ensure_preferences_record

        def edit
          edit_reset_preference_screen
        end

        def destroy
          destroy_reset_preference_screen
        end
      end
    end
  end
end
