# typed: false
# frozen_string_literal: true

module Core
  module Com
    class RootsController < Core::Com::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
