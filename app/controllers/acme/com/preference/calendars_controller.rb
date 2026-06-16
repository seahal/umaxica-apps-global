# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Preference
      class CalendarsController < Acme::Com::PreferencesBaseController
        include ::AcmePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
