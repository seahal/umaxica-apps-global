# typed: false
# frozen_string_literal: true

module Base
  module App
    class RootsController < Base::App::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
