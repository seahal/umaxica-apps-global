# typed: false
# frozen_string_literal: true

class PasskeyCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :default

  def perform
    Identity::PasskeyCeremony::TransactionPurger.call
  end
end
