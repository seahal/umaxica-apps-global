# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Web
      module V0
        class ThemesController < PreferencesBaseController
          include ::Preference::WebThemeEndpoint

          include ::Preference::WebThemeActions

          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false
        end
      end
    end
  end
end
