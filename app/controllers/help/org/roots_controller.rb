# typed: false
# frozen_string_literal: true

module Help
  module Org
    class RootsController < Help::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
