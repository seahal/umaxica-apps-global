# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jit/security/jwt/local_keyset_installer"
require "jit/security/jwt/registry"
require "openssl"

if Rails.env.local?
  Jit::Security::Jwt::LocalKeysetInstaller.install!
  ENV["AUTH_JWT_ISSUER"] ||= "urn:umaxica:test:auth"
  ENV["PREFERENCE_JWT_ISSUER"] ||= "urn:umaxica:test:preference"
end

Jit::Security::Jwt::Registry.configure!

module JwtConfig
  def self.private_key
    Jit::Security::Jwt::Keyring.private_key_for_active
  end

  def self.public_key
    Jit::Security::Jwt::Keyring.public_key_for_active
  end
end
