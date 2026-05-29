# typed: false
# frozen_string_literal: true

module Core
  module Org
    class AccountsController < PrivateController
      AUTHENTICATION_MODE = :private

      def index
        render template: "acme/org/accounts/index"
      end
    end
  end
end
