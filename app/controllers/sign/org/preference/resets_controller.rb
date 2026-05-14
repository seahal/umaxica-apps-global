# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class ResetsController < ApplicationController
        public_strict!
        include ::Preference::SignScreenActions

        preference_screen :reset
      end
    end
  end
end
