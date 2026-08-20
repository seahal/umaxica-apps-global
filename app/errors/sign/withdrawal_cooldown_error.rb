# typed: false
# frozen_string_literal: true

module Sign
  # Raised when attempting withdrawal-related operations during cooldown
  class WithdrawalCooldownError < WithdrawalError
    def initialize(withdraw_cooldown_until: nil)
      super(
        "sign.app.configuration.withdrawal.errors.cooldown_active",
        :unprocessable_content,
        withdraw_cooldown_until: withdraw_cooldown_until,
      )
    end
  end
end
