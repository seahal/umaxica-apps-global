# typed: false
# frozen_string_literal: true

module Palm
  module Org
    class RootsController < Palm::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: "Palm API is available for native and handheld clients. Browser access is not a product UI."
      end
    end
  end
end
