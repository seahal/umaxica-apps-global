# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class CookiesController < PreferencesBaseController
        include ::Preference::SignScreenActions

        preference_screen :cookie
      end
    end
  end
end
