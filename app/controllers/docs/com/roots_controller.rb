# typed: false
# frozen_string_literal: true

module Docs
  module Com
    class RootsController < Docs::Com::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
