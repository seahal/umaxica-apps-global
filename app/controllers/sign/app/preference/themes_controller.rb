# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class ThemesController < PreferencesBaseController
        include ::Preference::SignScreenActions

        preference_screen :theme
      end
    end
  end
end
