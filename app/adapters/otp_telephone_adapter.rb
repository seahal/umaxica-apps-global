# typed: false
# frozen_string_literal: true

class OtpTelephoneAdapter < OtpAdapter
  def deliver(record:, otp_code:, message_style: :default, **)
    OutboundSms.deliver_later(
      to: record.number,
      title: sms_title(otp_code, message_style),
      body: sms_body(otp_code, message_style),
    )
  end

  private

  def sms_title(otp_code, message_style)
    return localized_verification_message(otp_code) if message_style.to_sym == :localized_verification

    "Verification code"
  end

  def sms_body(otp_code, message_style)
    return localized_verification_message(otp_code) if message_style.to_sym == :localized_verification

    "Your verification code: #{otp_code}"
  end

  def localized_verification_message(otp_code)
    I18n.t("sign.telephone_verification.sms_message", code: otp_code)
  end
end
