# typed: false
# frozen_string_literal: true

class TelephoneCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform(batch_size: 500)
    Identity::TelephoneCeremony::TransactionPurger.new(batch_size: batch_size).call
  end
end
