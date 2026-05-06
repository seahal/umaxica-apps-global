# typed: false
# frozen_string_literal: true

module Sign
  # Raised when account deletion fails
  class WithdrawalDeletionError < WithdrawalError
    def initialize
      super("sign.withdrawal.errors.deletion_failed", :internal_server_error)
    end
  end
end
