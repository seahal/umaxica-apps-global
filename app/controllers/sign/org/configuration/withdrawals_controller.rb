# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class WithdrawalsController < PrivateController
        include ::Verification::Operator

        before_action :authenticate_operator!

        def show
        end

        private

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
