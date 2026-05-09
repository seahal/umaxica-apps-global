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
          "customer_emails=#{result.customer_emails_reencrypted}",
          "customer_telephones=#{result.customer_telephones_reencrypted}",
        ].join(" "),
      )
    end
  end
end
