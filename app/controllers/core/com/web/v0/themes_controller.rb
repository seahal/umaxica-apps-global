# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Web
      module V0
        class ThemesController < Core::Com::OpenController
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
