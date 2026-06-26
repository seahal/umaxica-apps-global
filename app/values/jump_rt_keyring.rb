# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"
require "jit_security_jwt_registry"

module JumpRtKeyring
  module_function

  def active_kid(namespace)
    JitSecurityJwtRegistry.surface(namespace).current_kid
  end

  def private_key(namespace)
    issuer = JitSecurityJwtRegistry.surface(namespace)
    JitSecurityJwtRegistry.private_key_for(issuer.id, issuer.current_kid)
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
