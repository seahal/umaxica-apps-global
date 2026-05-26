# typed: false
# frozen_string_literal: true

module Core
  module Org
    class RootsController < OpenController
      AUTHENTICATION_MODE = :open

      def index
        render template: "apex/org/roots/index"
      end
    end
  end
end
