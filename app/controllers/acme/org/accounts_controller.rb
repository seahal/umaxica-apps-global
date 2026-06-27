# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class AccountsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index
        authorize!(current_operator, to: :show?)
        @accounts = Agent.all
      end

      def show
        @account = find_account!
        authorize!(current_operator, to: :show?)
      end

      private

      def find_account!
        Agent.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
