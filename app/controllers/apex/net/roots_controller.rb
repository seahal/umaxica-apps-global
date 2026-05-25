# typed: false
# frozen_string_literal: true

module Apex
  module Net
    class RootsController < Apex::Net::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Apex::Net::Roots#index"
      end
    end
  end
end
