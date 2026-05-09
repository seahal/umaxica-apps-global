# typed: false
# frozen_string_literal: true

module Jump
  module Com
    class HealthController < Jump::PublicController
      include ::Health

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
