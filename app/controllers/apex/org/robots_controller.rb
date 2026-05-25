# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class RobotsController < BareController
      AUTHENTICATION_MODE = :bare

      include ::Robots

      def show
        show_plain_text
      end
    end
  end
end
