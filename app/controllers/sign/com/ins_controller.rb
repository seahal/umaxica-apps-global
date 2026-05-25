# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class InsController < In::GuestController
      AUTHENTICATION_MODE = :guest

      def new
      end
    end
  end
end
