# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class HealthsController < BareController
      include ::Health

      AUTHENTICATION_MODE = :bare

      def show
        show_plain_text
      end
    end
  end
end
