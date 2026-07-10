# typed: false
# frozen_string_literal: true

module Help
  module Org
    class RootsController < Help::Org::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
