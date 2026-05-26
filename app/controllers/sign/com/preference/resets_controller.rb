# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class ResetsController < PreferencesBaseController
        include ::Preference::SignScreenActions

        AUTHENTICATION_MODE = :open

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
