# typed: false
# frozen_string_literal: true

module Core
  module App
    class AccountsController < PrivateController
      AUTHENTICATION_MODE = :private

      def index
        render template: "apex/app/accounts/index"
      end
    end
  end
end
