# typed: false
# frozen_string_literal: true

module Docs
  module Com
    class RootsController < Docs::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
