# typed: false
# frozen_string_literal: true

namespace :db do
  namespace :encryption do
    desc "Re-encrypt identifier email/telephone columns under the current non-deterministic scheme"
    task reencrypt: :environment do
      result = IdentifierEncryptionReencrypt.new.call

      puts(
        [
          "user_emails=#{result.user_emails_reencrypted}",
          "user_telephones=#{result.user_telephones_reencrypted}",
          "staff_emails=#{result.staff_emails_reencrypted}",
          "staff_telephones=#{result.staff_telephones_reencrypted}",
          "visitor_emails=#{result.visitor_emails_reencrypted}",
          "visitor_telephones=#{result.visitor_telephones_reencrypted}",
        ].join(" "),
      )
    end
  end
end
