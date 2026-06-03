# typed: false
# frozen_string_literal: true

module Identity
  module StepUpCeremony
    class Transaction
      DEFAULT_TTL = 15.minutes
      STATUS_PENDING = "pending"
      STATUS_CONSUMED = "consumed"
    end
  end
end
