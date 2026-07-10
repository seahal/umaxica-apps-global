# typed: false
# frozen_string_literal: true

class SocialCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :default

  def perform
    IdentitySocialCeremonyTransactionPurger.call
  end
end
