# typed: false
# frozen_string_literal: true

module News
  module Com
    class RootsController < News::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
