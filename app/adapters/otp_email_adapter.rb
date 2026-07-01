# typed: false
# frozen_string_literal: true

class OtpEmailAdapter < OtpAdapter
  def initialize(mailer)
    @mailer = mailer
  end

  def deliver(record:, otp_code:, verification_token: nil, public_id: nil, **)
    @mailer.with(
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(otp_code),
      email_address: record.address,
      verification_token: verification_token,
      public_id: public_id,
    ).create.deliver_later
  end
end
