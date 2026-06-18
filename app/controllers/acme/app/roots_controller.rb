# typed: false
# frozen_string_literal: true

module Acme
  module App
    class RootsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
      end
    end
  end
end
