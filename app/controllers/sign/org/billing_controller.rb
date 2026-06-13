# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class BillingController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/billing")
      end
    end
  end
end
