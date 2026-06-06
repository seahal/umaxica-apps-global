# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class TimesController < Sign::Org::PreferencesBaseController
        include ::AcmePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
