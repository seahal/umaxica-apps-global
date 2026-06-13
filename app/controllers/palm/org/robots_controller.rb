# typed: false
# frozen_string_literal: true

module Palm
  module Org
    class RobotsController < BareController
      include ::Robots

      AUTHENTICATION_MODE = :bare

      def show
        show_plain_text
      end
    end
  end
end
