# typed: false
# frozen_string_literal: true

module Info
  module Com
    class RootsController < Info::Com::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
