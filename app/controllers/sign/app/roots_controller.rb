# typed: false
# frozen_string_literal: true

module Sign
  module App
    class RootsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
