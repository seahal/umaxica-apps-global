# typed: false
# frozen_string_literal: true

module Core
  module Net
    class RootsController < Core::Net::BareController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Core::Net::Roots#index"
      end
    end
  end
end
