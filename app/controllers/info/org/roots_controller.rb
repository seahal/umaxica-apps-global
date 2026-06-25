# typed: false
# frozen_string_literal: true

module Info
  module Org
    class RootsController < Info::Org::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
