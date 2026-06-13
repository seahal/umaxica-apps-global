# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
