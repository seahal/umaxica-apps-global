# typed: false
# frozen_string_literal: true

module Notify
  module Com
    # Delivers an OTP to a visitor on the com surface.
    # See Notify::App::OtpNotifier for why each surface has its own notifier.
    class OtpNotifier < Notify::ApplicationNotifier
      extend Notify::OtpIssuance

      deliver_by :email do |config|
        config.mailer = "Email::Com::OtpMailer"
        config.method = :create
        config.params =
          -> {
            {
              encrypted_hotp_token: params[:encrypted_hotp_token],
              email_address: recipient.address,
              verification_token: params[:verification_token],
              public_id: params[:public_id],
            }
          }
      end
    end
  end
end
