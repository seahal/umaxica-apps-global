# typed: false
# frozen_string_literal: true

module Apex
  module Dev
    class RootsController < Apex::Dev::ApplicationController
      def index
        render plain: "Apex::Dev::Roots#index"
      end
    end
  end
end
