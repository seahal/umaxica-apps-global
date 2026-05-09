# typed: false
# frozen_string_literal: true

module Sign
  module Net
    class HealthController < Sign::PublicController
      include ::Health

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
