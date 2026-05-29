# typed: false
# frozen_string_literal: true

module Core
  module Com
    class AccountsController < Core::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      def index
        render template: "acme/com/accounts/index"
      end
    end
  end
end
