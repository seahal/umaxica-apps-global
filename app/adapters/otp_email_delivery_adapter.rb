# typed: false
# frozen_string_literal: true

class OtpEmailDeliveryAdapter < OtpDeliveryAdapter
  def initialize(mailer)
    @mailer = mailer
  end

  def deliver(encrypted_hotp_token:, email_address:, **)
    @mailer.with(
      encrypted_hotp_token: encrypted_hotp_token,
      email_address: email_address,
    ).create.deliver_later
  end
end
