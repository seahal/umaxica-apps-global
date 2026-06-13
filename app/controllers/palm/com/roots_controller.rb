# typed: false
# frozen_string_literal: true

module Palm
  module Com
    class RootsController < Palm::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
