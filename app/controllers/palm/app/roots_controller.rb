# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RootsController < Palm::App::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
