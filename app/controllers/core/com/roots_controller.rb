# typed: false
# frozen_string_literal: true

module Core
  module Com
    class RootsController < OpenController
      AUTHENTICATION_MODE = :open

      def index
        render template: "apex/com/roots/index"
      end
    end
  end
end
