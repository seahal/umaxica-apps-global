# typed: false
# frozen_string_literal: true

module Docs
  module App
    class RootsController < Docs::App::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
