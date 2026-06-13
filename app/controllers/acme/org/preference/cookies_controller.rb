# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Preference
      class CookiesController < Acme::Org::PreferencesBaseController
        include ::AcmePreferenceScreenDispatch

        AUTHENTICATION_MODE = :open

        before_action :ensure_preferences_record
      end
    end
  end
end
