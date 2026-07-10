# typed: false
# frozen_string_literal: true

module Core
  module Org
    class RootsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
