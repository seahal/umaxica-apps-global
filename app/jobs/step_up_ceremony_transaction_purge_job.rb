# typed: false
# frozen_string_literal: true

class StepUpCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform(batch_size: 500)
    IdentityStepUpCeremonyTransactionPurger.new(batch_size: batch_size).call
  end
end
