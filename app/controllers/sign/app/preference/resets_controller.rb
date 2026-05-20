# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class ResetsController < PreferencesBaseController
        include ::Preference::SignScreenActions

        preference_screen :reset
      end
    end
  end
end
