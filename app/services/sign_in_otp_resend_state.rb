# typed: false
# frozen_string_literal: true

module SignInOtpResendState
  PURPOSE = "sign-in-otp-resend"
  TTL = 30.minutes
  ENCRYPTOR_CACHE = Concurrent::Map.new

  module_function

  def issue(kind:, target:)
    encryptor.encrypt_and_sign(
      {
        "kind" => kind.to_s,
        "target" => target.to_s,
      },
      purpose: PURPOSE,
      expires_in: TTL,
    )
  end

  def parse(token)
    return nil if token.blank?

    payload = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
    kind = payload["kind"].to_s
    target = payload["target"].to_s
    return nil if kind.blank? || target.blank?

    { kind: kind, target: target }
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def encryptor
    ENCRYPTOR_CACHE.compute_if_absent(PURPOSE) do
      secret_credential = Rails.application.secret_key_base
      key_len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(secret_credential).generate_key(PURPOSE, key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
