# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

namespace :identifier_hmac do
  desc "Emergency overwrite of email/telephone HMAC digest columns after HMAC key replacement"
  task emergency_rotate: :environment do
    unless ENV["CONFIRM_IDENTIFIER_HMAC_OVERWRITE"] == "1"
      message = "Refusing to overwrite identifier HMAC digests. Set CONFIRM_IDENTIFIER_HMAC_OVERWRITE=1 " \
                "after stopping identifier writes."
      abort(message)
    end

    result = IdentifierHmacEmergencyRotation.new.call

    puts(
      [
        "user_emails=#{result.user_emails_updated}",
        "user_telephones=#{result.user_telephones_updated}",
        "staff_emails=#{result.staff_emails_updated}",
        "staff_telephones=#{result.staff_telephones_updated}",
        "visitor_emails=#{result.visitor_emails_updated}",
        "visitor_telephones=#{result.visitor_telephones_updated}",
        "records_failed=#{result.records_failed}",
      ].join(" "),
    )

    abort "Identifier HMAC overwrite completed with failures." if result.records_failed.positive?
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
