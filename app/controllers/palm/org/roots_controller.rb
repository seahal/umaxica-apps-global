# typed: false
# frozen_string_literal: true

module Palm
  module Org
    class RootsController < Palm::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
