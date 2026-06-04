# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class CookiesController < Sign::App::PreferencesBaseController
        include ::Acme::PreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
