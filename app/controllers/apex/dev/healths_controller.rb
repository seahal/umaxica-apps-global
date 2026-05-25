# typed: false
# frozen_string_literal: true

module Apex
  module Dev
    class HealthsController < BareController
      AUTHENTICATION_MODE = :bare

      include ::Health

      def show
        show_plain_text
      end
    end
  end
end
