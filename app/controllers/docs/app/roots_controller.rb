# typed: false
# frozen_string_literal: true

module Docs
  module App
    class RootsController < Docs::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
