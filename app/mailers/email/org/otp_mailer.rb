# typed: false
# frozen_string_literal: true

module Email::Org
  class OtpMailer < ApplicationMailer
    default from: "otp@umaxica.org"

    layout "email/application"

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      @verification_token = params[:verification_token]
      @public_id = params[:public_id]
      @verification_url = verification_url

      mail(
        to: params[:email_address],
        subject: I18n.t("mail.email.org.otp_mailer.create.subject"),
      )
    end

    private

    def verification_url
      return if @verification_token.blank? || @public_id.blank?

      Rails.application.routes.url_helpers.edit_auth_org_settings_emails_registration_url(
        token: @verification_token,
        host: ENV.fetch("PRIVATE_AUTH_STAFF_URL"),
      )
    end
  end
end
