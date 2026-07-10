# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Preference
      class LanguagesController < Base::Org::PreferencesBaseController
        include ::BasePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
