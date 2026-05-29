# typed: false
# frozen_string_literal: true

module Core
  module Org
    class RootsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :open

      def index
        render template: "acme/org/roots/index"
      end
    end
  end
end
