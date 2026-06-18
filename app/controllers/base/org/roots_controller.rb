# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
