# typed: false
# frozen_string_literal: true

module Help
  module Com
    class RootsController < Help::Com::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
