# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class RootsController < ::Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
