# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      module Region
        class LanguagesController < PreferencesBaseController
          include ::Preference::SignScreenActions

          preference_screen :language
        end
      end
    end
  end
end
