# typed: false
# frozen_string_literal: true

module Info
  module App
    class RootsController < Info::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
