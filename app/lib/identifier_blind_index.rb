# typed: false
# frozen_string_literal: true

require "openssl"

module IdentifierBlindIndex
  module_function

  def normalize_email(value)
    JitUtilsEmailValidator.normalize(value)
  end

  def normalize_telephone(value)
    TelephoneNormalization.normalize_to_e164(value.to_s.strip)
  end

  def bidx_for_email(value)
    normalized = normalize_email(value)
    return nil if normalized.blank?

    digest(:email, normalized, secret_credential_for_email)
  end

  def bidx_for_telephone(value)
    normalized = normalize_telephone(value)
    return nil if normalized.blank?

    digest(:telephone, normalized, secret_credential_for_telephone)
  end

  def digest(kind, normalized_identifier, secret_credential_value)
    OpenSSL::HMAC.hexdigest("SHA256", secret_credential_value, "#{kind}:#{normalized_identifier}")
  end

  def secret_credential_for_email
    required_secret_credential(:EMAIL_ADDRESS_HMAC_SALT)
  end

  def secret_credential_for_telephone
    required_secret_credential(:TELEPHONE_NUMBER_HMAC_SALT)
  end

  def required_secret_credential(key)
    Rails.app.creds.option(key).presence || required_env_secret_credential(key)
  end

  def required_env_secret_credential(key)
    ENV.fetch(key.to_s).presence || raise_missing_secret_credential(key)
  rescue KeyError
    raise_missing_secret_credential(key)
  end

  def raise_missing_secret_credential(key)
    raise KeyError, "Missing key: [:#{key}]"
  end
end
