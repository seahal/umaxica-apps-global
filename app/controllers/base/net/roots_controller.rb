# typed: false
# frozen_string_literal: true

module Base
  module Net
    class RootsController < Base::Net::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Base::Net::Roots#index"
      end
    end
  end
end
