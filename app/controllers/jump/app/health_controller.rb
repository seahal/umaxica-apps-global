# typed: false
# frozen_string_literal: true

module Jump
  module App
    class HealthController < Jump::PublicController
      include ::Health

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
