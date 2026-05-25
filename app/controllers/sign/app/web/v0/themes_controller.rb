# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Web
      module V0
        class ThemesController < PreferencesBaseController
          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open
          include ::Preference::WebThemeEndpoint
          include ::Preference::WebThemeActions

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false
        end
      end
    end
  end
end
