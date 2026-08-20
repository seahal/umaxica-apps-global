# typed: false
# frozen_string_literal: true

module Sign
  # Raised when attempting recovery outside the allowed window
  class WithdrawalRecoveryNotAvailableError < WithdrawalError
    def initialize
      super("sign.withdrawal.errors.recovery_not_available", :unprocessable_content)
    end
  end
end
