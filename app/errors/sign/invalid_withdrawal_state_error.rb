# typed: false
# frozen_string_literal: true

module Sign
  # Raised when withdrawal cannot be shown due to invalid user state
  class InvalidWithdrawalStateError < WithdrawalError
    def initialize(current_status)
      super("sign.withdrawal.errors.invalid_state", :unprocessable_entity, current_status: current_status)
    end
  end
end
