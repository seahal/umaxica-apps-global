# typed: false
# frozen_string_literal: true

module Sign
  module App
    class RootsController < GuestController
      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
      end
    end
  end
end
