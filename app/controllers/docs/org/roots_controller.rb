# typed: false
# frozen_string_literal: true

module Docs
  module Org
    class RootsController < Docs::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
