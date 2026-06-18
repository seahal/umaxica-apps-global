# typed: false
# frozen_string_literal: true

module News
  module App
    class RootsController < News::App::BareController
      AUTHENTICATION_MODE = :bare
      layout false

      def index
      end
    end
  end
end
