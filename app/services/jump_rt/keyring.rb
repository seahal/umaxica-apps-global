# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"
require "jit/security/jwt/registry"

module JumpRt
  module Keyring
    module_function

    def active_kid(namespace)
      Jit::Security::Jwt::Registry.surface(namespace).current_kid
    end

    def private_key(namespace)
      issuer = Jit::Security::Jwt::Registry.surface(namespace)
      Jit::Security::Jwt::Registry.private_key_for(issuer.id, issuer.current_kid)
    end

    def decode_private_key(value)
      return nil if value.blank?

      raw = value.to_s
      return OpenSSL::PKey.read(raw) if raw.include?("BEGIN")

      OpenSSL::PKey::EC.new(Base64.decode64(raw))
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      nil
    end
  end
end
