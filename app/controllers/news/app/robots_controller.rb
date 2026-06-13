# typed: false
# frozen_string_literal: true

module News
  module App
    class RobotsController < BareController
      include ::Robots

      AUTHENTICATION_MODE = :bare

      def show
        show_plain_text
      end
    end
  end
end
