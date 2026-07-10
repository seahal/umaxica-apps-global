# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class BillingController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/billing")
      end
    end
  end
end
