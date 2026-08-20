# typed: false
# frozen_string_literal: true

module Sign
  # Raised when account withdrawal is finalized and further actions are blocked
  class WithdrawalFinalizedError < WithdrawalError
    def initialize
      super("sign.app.configuration.withdrawal.errors.finalized", :unprocessable_content)
    end
  end
end
