# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class RegionsController < ApplicationController
        public_strict!
        include ::Preference::SignScreenActions

        preference_screen :region
      end
    end
  end
end
