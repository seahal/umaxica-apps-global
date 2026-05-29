# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class RootsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :open

      def index
      end
    end
  end
end
