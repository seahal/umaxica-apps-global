# typed: false
# frozen_string_literal: true

module Base
  module App
    module Web
      module V0
        class ThemesController < Base::App::ApplicationController
          include ::PreferenceWebThemeEndpoint

          include ::PreferenceWebThemeActions

          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false
          skip_before_action :set_color_theme, raise: false
        end
      end
    end
  end
end
