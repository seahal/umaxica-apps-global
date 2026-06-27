# typed: false
# frozen_string_literal: true

module Base
  module Com
    class AccountsController < Base::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index
        authorize!(current_visitor, to: :show?)
        @accounts = Individual.all
      end

      def show
        @account = find_account!
        authorize!(current_visitor, to: :show?)
      end

      private

      def find_account!
        Individual.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
