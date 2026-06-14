# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SignedOutsController < BareController
      AUTHENTICATION_MODE = :bare

      def show
      end
    end
  end
end
