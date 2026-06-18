# typed: false
# frozen_string_literal: true

module Help
  module App
    class RootsController < Help::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
