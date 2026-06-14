# typed: false
# frozen_string_literal: true

module Help
  module Com
    class RootsController < Help::Com::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
