# typed: false
# frozen_string_literal: true

module Base
  module App
    module Preference
      class CustomizationsController < Base::App::PreferencesBaseController
        include ::PreferenceSignScreenActions
        include ::BasePreferenceScreenPage

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record

        def edit
          edit_reset_preference_screen
          return if performed?

          render inertia: preference_customization_component, props: preference_customization_page_props
        end

        def destroy
          destroy_reset_preference_screen
        end
      end
    end
  end
end
