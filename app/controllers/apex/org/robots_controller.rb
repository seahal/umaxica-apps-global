# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class RobotsController < Apex::PublicController
      include ::Robots

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
