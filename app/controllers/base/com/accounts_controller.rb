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
        @accounts = switcher.available_accounts
      end

      def show
        @account = find_account!
        authorize!(@account, to: :show?, with: AccountPolicy)
      end

      private

      def find_account!
        switcher.find_account(params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :com, principal: current_visitor, session: current_session,
        )
      end
    end
  end
end
