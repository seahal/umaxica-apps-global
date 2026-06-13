# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
