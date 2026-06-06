# typed: false
# frozen_string_literal: true

module Email::Com
  class OtpMailer < ApplicationMailer
    default from: "otp@umaxica.com"

    layout "email/application"

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      @verification_token = params[:verification_token]
      @public_id = params[:public_id]
      @verification_url = verification_url

      mail(
        to: params[:email_address],
        subject: I18n.t("mail.email.com.otp_mailer.create.subject"),
      )
    end

    private

    def verification_url
      return if @verification_token.blank? || @public_id.blank?

      Rails.application.routes.url_helpers.edit_sign_com_settings_email_url(
        @public_id,
        token: @verification_token,
        host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
      )
    end
  end
end
