# typed: false
# frozen_string_literal: true

module News
  module Org
    class RootsController < News::Org::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
