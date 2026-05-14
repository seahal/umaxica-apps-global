# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class CookiesController < ApplicationController
        public_strict!
        include ::Preference::SignScreenActions

        preference_screen :cookie
      end
    end
  end
end
