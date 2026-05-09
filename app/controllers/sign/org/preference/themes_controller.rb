# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class ThemesController < ApplicationController
        public_strict!
        include ::Preference::Core

        def edit
          set_colortheme_preferences_edit
          @preference_theme = @preference_colortheme
        end

        def update
          set_colortheme_preferences_update
          @preference_theme = @preference_colortheme
          return render_preference_update_response if request.format.json?

          redirect_to(
            safe_return_to_path || edit_sign_org_preference_theme_url,
            notice: t("apex.org.preferences.update_success"),
          )
        end
      end
    end
  end
end
