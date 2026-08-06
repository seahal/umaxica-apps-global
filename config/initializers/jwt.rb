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
  # Development and test defaults only. In production AuthenticationJwtConfiguration
  # raises for a missing audience rather than falling back to a shared literal,
  # which would let a token minted for one resource type validate as another.
  ENV["AUTH_JWT_AUDIENCES"] ||= "umaxica-api"
end

JitSecurityJwtRegistry.configure!

Rails.application.config.after_initialize do
  OidcClientRegistry.validate_private_key_jwt_configuration!
end

module JwtConfig
  def self.private_key
    JitSecurityJwtKeyring.private_key_for_active
  end

  def self.public_key
    JitSecurityJwtKeyring.public_key_for_active
  end
end
