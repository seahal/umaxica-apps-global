# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class RegionsController < PreferencesBaseController
        include ::Preference::SignScreenActions

        before_action :ensure_preferences_record

        def edit
          edit_region_preference_screen
        end

        def update
          update_region_preference_screen
        end
      end
    end
  end
end
