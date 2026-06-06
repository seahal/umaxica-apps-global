# typed: false
# frozen_string_literal: true

require "openssl"

module OccurrenceHmac
  module_function

  class MissingSecretError < ApplicationError
    def initialize
      super("errors.occurrence.missing_hmac_secret_credential")
    end
  end

  class InvalidTelephoneFormatError < ApplicationError
    def initialize
      super("errors.occurrence.invalid_telephone_format")
    end
  end

  def email_hmac(email)
    normalized = email.to_s.strip.downcase
    digest(kind: :email, body: normalized)
  end

  def telephone_hmac(telephone)
    normalized = telephone.to_s.strip
    raise InvalidTelephoneFormatError if normalized.blank?
    raise InvalidTelephoneFormatError unless normalized.start_with?("+")
    raise InvalidTelephoneFormatError unless normalized.match?(/\A\+\d+\z/)

    digest(kind: :telephone, body: normalized)
  end

  def ip_hmac(ip)
    normalized = ip.to_s.strip
    digest(kind: :ip, body: normalized)
  end

  def digest(kind:, body:)
    OpenSSL::HMAC.hexdigest("SHA256", secret_credential, "#{kind}:#{body}")
  end

  def secret_credential
    secret_credential_value = Rails.app.creds.option(:OCCURRENCE_HMAC_SECRET)
    raise MissingSecretError if secret_credential_value.blank?

    secret_credential_value
  end
end
