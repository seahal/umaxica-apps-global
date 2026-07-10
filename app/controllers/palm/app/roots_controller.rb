# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RootsController < Palm::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
