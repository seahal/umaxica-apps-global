# typed: false
# frozen_string_literal: true

module Core
  module Dev
    class RootsController < Core::Dev::BareController
      AUTHENTICATION_MODE = :deny_all

      def index
        render plain: "Core::Dev::Roots#index"
      end
    end
  end
end
