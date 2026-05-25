# typed: false
# frozen_string_literal: true

module Sign
  module App
    class UpsController < Up::GuestController
      AUTHENTICATION_MODE = :guest

      def new
      end
    end
  end
end
