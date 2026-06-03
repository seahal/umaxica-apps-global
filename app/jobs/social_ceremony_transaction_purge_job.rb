# typed: false
# frozen_string_literal: true

class SocialCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :default

  def perform
    Identity::SocialCeremony::TransactionPurger.call
  end
end
