# typed: false
# frozen_string_literal: true

module Docs
  module Org
    class RootsController < Docs::Org::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
