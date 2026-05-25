# typed: false
# frozen_string_literal: true

module Apex
  module Dev
    class RootsController < Apex::Dev::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Apex::Dev::Roots#index"
      end
    end
  end
end
