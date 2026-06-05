# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Web
      module V0
        class ThemesController < PreferencesBaseController
          include ::Preference::WebThemeEndpoint

          include ::Preference::WebThemeActions

          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false

          private

          def redirect_localhost_preference_authority!
            # Sign owns the web preference JSON authority. The localhost HTML
            # compatibility redirect must not intercept these API endpoints.
          end
        end
      end
    end
  end
end
