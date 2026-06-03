# typed: false
# frozen_string_literal: true

class TotpCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :default

  def perform
    Identity::TotpCeremony::TransactionPurger.new.call
  end
end
