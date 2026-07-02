# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      class WithdrawalsController < ::Auth::Org::ApplicationController
        include ::VerificationOperator

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :authorize_withdrawal!, only: :show

        def show
          render "auth/org/settings/withdrawals/show"
        end

        private

        def authorize_withdrawal!
          authorize!(current_operator, to: :show?, with: OperatorWithdrawalPolicy)
        end

        def verification_required_action? = true

        def verification_scope = "operator_lifecycle"
      end
    end
  end
end
