# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class AccountsController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/accounts")
      end
    end
  end
end
