# typed: false
# frozen_string_literal: true

module Base
  module App
    module Preference
      class ThemesController < Base::App::PreferencesBaseController
        include ::BasePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
