# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    class RootsController < Acme::Dev::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Acme::Dev::Roots#index"
      end
    end
  end
end
