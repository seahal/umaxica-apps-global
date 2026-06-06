# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class LanguagesController < Sign::App::PreferencesBaseController
        include ::AcmePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
