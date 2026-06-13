# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: "Base services are available. See /settings."
      end
    end
  end
end
