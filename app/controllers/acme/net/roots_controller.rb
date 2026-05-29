# typed: false
# frozen_string_literal: true

module Acme
  module Net
    class RootsController < Acme::Net::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Acme::Net::Roots#index"
      end
    end
  end
end
