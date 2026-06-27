# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class AccountsController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/accounts")
      end
    end
  end
end
