# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      class ThemesController < Base::Com::PreferencesBaseController
        include ::BasePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
