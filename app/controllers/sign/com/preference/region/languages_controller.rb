# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      module Region
        class LanguagesController < ApplicationController
          public_strict!
          include ::Preference::SignScreenActions

          preference_screen :language
        end
      end
    end
  end
end
