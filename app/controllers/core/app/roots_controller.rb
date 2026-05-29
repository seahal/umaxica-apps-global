# typed: false
# frozen_string_literal: true

module Core
  module App
    class RootsController < Core::App::ApplicationController
      AUTHENTICATION_MODE = :open

      def index
        render template: "acme/app/roots/index"
      end
    end
  end
end
