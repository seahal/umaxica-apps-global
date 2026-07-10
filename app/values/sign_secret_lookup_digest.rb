# typed: false
# frozen_string_literal: true

require "openssl"

module SignSecretLookupDigest
  module_function

  def digest(raw_secret_credential)
    OpenSSL::HMAC.hexdigest("SHA256", secret_key, raw_secret_credential.to_s)
  end

  def secret_key
    Rails.application.secret_key_base.presence ||
      raise(KeyError, "Missing key: Rails.application.secret_key_base")
  end
end
