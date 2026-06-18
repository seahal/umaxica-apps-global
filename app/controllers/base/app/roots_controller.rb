# typed: false
# frozen_string_literal: true

module Base
  module App
    class RootsController < Base::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
