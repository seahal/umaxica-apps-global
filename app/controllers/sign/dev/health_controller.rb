# typed: false
# frozen_string_literal: true

module Sign
  module Dev
    class HealthController < Sign::Dev::ApplicationController
      include ::Health

      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
