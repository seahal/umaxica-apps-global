# typed: false
# frozen_string_literal: true

require "openssl"

module IdentifierBlindIndex
  module_function

  def normalize_email(value)
    Jit::Utils::EmailValidator.normalize(value)
  end

  def normalize_telephone(value)
    TelephoneNormalization.normalize_to_e164(value.to_s.strip)
  end

  def bidx_for_email(value)
    normalized = normalize_email(value)
    return nil if normalized.blank?

    digest(:email, normalized, secret_for_email)
  end

  def bidx_for_telephone(value)
    normalized = normalize_telephone(value)
    return nil if normalized.blank?

    digest(:telephone, normalized, secret_for_telephone)
  end

  def digest(kind, normalized_identifier, secret_value)
    OpenSSL::HMAC.hexdigest("SHA256", secret_value, "#{kind}:#{normalized_identifier}")
  end

  def secret_for_email
    Rails.app.creds.option(:EMAIL_ADDRESS_HMAC_SALT).presence ||
      ENV["EMAIL_ADDRESS_HMAC_SALT"].presence ||
      raise(KeyError, "Missing key: [:EMAIL_ADDRESS_HMAC_SALT]")
  end

  def secret_for_telephone
    Rails.app.creds.option(:TELEPHONE_NUMBER_HMAC_SALT).presence ||
      ENV["TELEPHONE_NUMBER_HMAC_SALT"].presence ||
      raise(KeyError, "Missing key: [:TELEPHONE_NUMBER_HMAC_SALT]")
  end
end
