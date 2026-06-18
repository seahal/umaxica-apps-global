# typed: false
# frozen_string_literal: true

module News
  module Org
    class RootsController < News::Org::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
