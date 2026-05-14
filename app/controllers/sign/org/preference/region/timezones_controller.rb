# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      module Region
        class TimezonesController < ApplicationController
          public_strict!
          include ::Preference::SignScreenActions

          preference_screen :timezone
        end
      end
    end
  end
end
