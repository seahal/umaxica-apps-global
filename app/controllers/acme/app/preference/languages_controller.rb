# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Preference
      class LanguagesController < Acme::App::PreferencesBaseController
        include ::AcmePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
