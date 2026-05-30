# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class WithdrawalsController < Sign::Org::ApplicationController
        include ::Verification::Operator

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): only the operator may view their own withdrawal
        # landing page. Uses OperatorWithdrawalPolicy#show? (owner-self). Step-up guards remain below.
        before_action :authorize_withdrawal!, only: :show

        def show
        end

        private

        def authorize_withdrawal!
          authorize!(current_operator, to: :show?, with: OperatorWithdrawalPolicy)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "withdrawal"
        end
      end
    end
  end
end
