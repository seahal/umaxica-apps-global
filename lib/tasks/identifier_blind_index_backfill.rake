# typed: false
# frozen_string_literal: true

namespace :identifier_blind_index do
  desc "Backfill blind-index digests for user and staff email/telephone rows"
  task backfill: :environment do
    result = IdentifierBlindIndexBackfill.new.call

    puts(
      [
        "user_emails=#{result.user_emails_updated}",
        "user_telephones=#{result.user_telephones_updated}",
        "staff_emails=#{result.staff_emails_updated}",
        "staff_telephones=#{result.staff_telephones_updated}",
      ].join(" "),
    )
  end
end
