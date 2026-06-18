# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
