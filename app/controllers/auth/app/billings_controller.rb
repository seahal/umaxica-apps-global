# typed: false
# frozen_string_literal: true

module Auth
  module App
    class BillingsController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/billings")
      end
    end
  end
end
