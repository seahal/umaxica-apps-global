# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Preference
      class ResetsController < Acme::Org::PreferencesBaseController
        include ::Preference::SignScreenActions

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record

        def edit
          edit_reset_preference_screen
          render "acme/shared/preference/resets" unless performed?
        end

        def destroy
          destroy_reset_preference_screen
        end
      end
    end
  end
end
