# typed: false
# frozen_string_literal: true

module Notify
  # The entry point every OTP notifier exposes, extended into each surface.
  #
  # The OTP is encrypted here, synchronously, in the caller's process and before
  # `with` is reached. Noticed serializes `params` verbatim into the delivery job,
  # so this is the only point at which the plaintext code can be kept out of the
  # job arguments. `otp_code` stays a local and never enters `params`.
  #
  # The arguments are validated explicitly because Noticed::Ephemeral#deliver does
  # not call validate!, which would make a declared `required_params` a silent
  # no-op rather than an error.
  module OtpIssuance
    def issue(record:, otp_code:, verification_token: nil, public_id: nil)
      raise ArgumentError, "record is required to issue an otp email" if record.nil?

      with(
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
        verification_token: verification_token,
        public_id: public_id,
      ).deliver(record)
    end
  end
end
