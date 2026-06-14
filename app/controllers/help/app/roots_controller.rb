# typed: false
# frozen_string_literal: true

module Help
  module App
    class RootsController < Help::App::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render plain: t(".message")
      end
    end
  end
end
