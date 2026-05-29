# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class RootsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :open

      def index
      end
    end
  end
end
