# typed: false
# frozen_string_literal: true

module News
  module App
    class RootsController < News::App::BareController
      AUTHENTICATION_MODE = :bare

      def index
        render layout: false
      end
    end
  end
end
