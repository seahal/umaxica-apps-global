# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Preference
      class ResetsController < Base::Org::PreferencesBaseController
        include ::PreferenceSignScreenActions

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record

        def edit
          edit_reset_preference_screen
          render "base/shared/preference/resets" unless performed?
        end

        def destroy
          destroy_reset_preference_screen
        end
      end
    end
  end
end
