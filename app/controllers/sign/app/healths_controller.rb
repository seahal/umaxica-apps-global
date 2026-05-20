# typed: false
# frozen_string_literal: true

module Sign
  module App
    class HealthsController < BareController
      include ::Health

      def show
        show_plain_text
      end
    end
  end
end
