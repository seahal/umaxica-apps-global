# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class RootsController < ::Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
