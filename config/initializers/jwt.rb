# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jit_security_jwt_local_keyset_installer"
require "jit_security_jwt_registry"
require "openssl"

if Rails.env.local?
  JitSecurityJwtLocalKeysetInstaller.install!
  ENV["AUTH_JWT_ISSUER"] ||= "urn:umaxica:test:auth"
  ENV["PREFERENCE_JWT_ISSUER"] ||= "urn:umaxica:test:preference"
end

JitSecurityJwtRegistry.configure!

module JwtConfig
  def self.private_key
    JitSecurityJwtKeyring.private_key_for_active
  end

  def self.public_key
    JitSecurityJwtKeyring.public_key_for_active
  end
end
