# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class CookiesController < PreferencesBaseController
        include ::Preference::SignScreenActions

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record

        def edit
          edit_cookie_preference_screen
        end

        def update
          update_cookie_preference_screen
        end
      end
    end
  end
end
