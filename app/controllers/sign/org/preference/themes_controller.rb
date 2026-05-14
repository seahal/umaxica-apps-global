# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class ThemesController < ApplicationController
        public_strict!
        include ::Preference::SignScreenActions

        preference_screen :theme
      end
    end
  end
end
