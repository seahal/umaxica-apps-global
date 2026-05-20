# typed: false
# frozen_string_literal: true

module Sign
  # Assigns an OTP to a telephone record and enqueues the matching SMS payload.
  class TelephoneOtpDelivery
    OTP_EXPIRATION_MINUTES = 12

    def self.assign(telephone, now: Time.current)
      new(telephone, now: now).assign
    end

    # The OTP must travel in the SMS body, but it must not be echoed into the
    # SNS Subject (title): that subject is delivery metadata, not the message,
    # and duplicating the code there only widens the leak surface.
    def self.deliver!(telephone, otp_code)
      Outbound::Sms.deliver_later(
        to: telephone.number,
        title: "Verification code",
        body: "Your verification code: #{otp_code}",
      )
    end

    def initialize(telephone, now:)
      @telephone = telephone
      @now = now
    end

    def assign
      otp_private_key = ROTP::Base32.random_base32
      otp_count_number = otp_counter
      otp_code = ROTP::HOTP.new(otp_private_key).at(otp_count_number).to_s

      @telephone.otp_private_key = otp_private_key
      @telephone.otp_counter = otp_count_number
      @telephone.otp_expires_at = OTP_EXPIRATION_MINUTES.minutes.from_now
      @telephone.otp_last_sent_at = @now if @telephone.respond_to?(:otp_last_sent_at=)

      otp_code
    end

    private

    def otp_counter
      Integer([Time.now.to_i, SecureRandom.random_number(1 << 64)].map(&:to_s).join, 10)
    end
  end
end
