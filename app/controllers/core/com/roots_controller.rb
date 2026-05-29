# typed: false
# frozen_string_literal: true

module Core
  module Com
    class RootsController < Core::Com::ApplicationController
      AUTHENTICATION_MODE = :open

      def index
        render template: "acme/com/roots/index"
      end
    end
  end
end
