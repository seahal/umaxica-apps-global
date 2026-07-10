# typed: false
# frozen_string_literal: true

module Core
  module App
    class RootsController < Core::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
