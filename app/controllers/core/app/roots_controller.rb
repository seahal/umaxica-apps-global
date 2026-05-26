# typed: false
# frozen_string_literal: true

module Core
  module App
    class RootsController < OpenController
      AUTHENTICATION_MODE = :open

      def index
        render template: "apex/app/roots/index"
      end
    end
  end
end
