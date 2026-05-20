# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class RobotsController < BareController
      include ::Robots

      def show
        show_plain_text
      end
    end
  end
end
