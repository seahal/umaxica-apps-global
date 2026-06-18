# typed: false
# frozen_string_literal: true

module News
  module Com
    class RootsController < News::Com::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
