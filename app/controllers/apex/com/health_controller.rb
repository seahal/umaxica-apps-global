# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class HealthController < Apex::PublicController
      include ::Health

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
