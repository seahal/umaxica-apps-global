# typed: false
# frozen_string_literal: true

module Apex
  module Net
    class RootsController < Apex::Net::ApplicationController
      def index
        render plain: "Apex::Net::Roots#index"
      end
    end
  end
end
