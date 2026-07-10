# typed: false
# frozen_string_literal: true

module OutboundSensitivePayload
  SMS_BODY_PURPOSE = "outbound.sms.body"
  EMAIL_OTP_PURPOSE = "outbound.email.otp"
  ENCRYPTOR_CACHE = Concurrent::Map.new

  module_function

  def encrypt_sms_body(body)
    encrypt(body, purpose: SMS_BODY_PURPOSE)
  end

  def decrypt_sms_body(token)
    decrypt(token, purpose: SMS_BODY_PURPOSE)
  end

  def encrypt_email_otp(hotp_token)
    encrypt(hotp_token, purpose: EMAIL_OTP_PURPOSE)
  end

  def decrypt_email_otp(token)
    decrypt(token, purpose: EMAIL_OTP_PURPOSE)
  end

  def encrypt(value, purpose:)
    raise ArgumentError, "Sensitive payload cannot be blank" if value.blank?

    encryptor(purpose).encrypt_and_sign(value.to_s, purpose: purpose)
  end

  def decrypt(token, purpose:)
    raise ArgumentError, "Encrypted sensitive payload cannot be blank" if token.blank?

    encryptor(purpose).decrypt_and_verify(token, purpose: purpose)
  end

  def encryptor(purpose)
    ENCRYPTOR_CACHE.compute_if_absent(purpose) do
      secret_credential = Rails.application.secret_key_base
      key_len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(secret_credential).generate_key(purpose, key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
