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
  # Development and test defaults remain resource-specific so local execution
  # exercises the same audience isolation required in production.
  ENV["AUTH_JWT_CLIENT_AUDIENCES"] ||= "umaxica-api-client"
  ENV["AUTH_JWT_VISITOR_AUDIENCES"] ||= "umaxica-api-visitor"
  ENV["AUTH_JWT_OPERATOR_AUDIENCES"] ||= "umaxica-api-operator"
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
