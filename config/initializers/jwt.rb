# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jit/security/jwt/registry"
require "openssl"

if Rails.env.local?
  require "jwt"

  def install_test_jwt_keyset!(prefix, kid)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_jwk = JWT::JWK.new(key, kid).export.transform_keys(&:to_s).merge(
      "alg" => "ES384",
      "use" => "sig",
      "state" => "active",
    )
    ENV["#{prefix}_JWT_ACTIVE_KID"] = kid
    ENV["#{prefix}_JWT_PRIVATE_KEYSET"] = JSON.generate(kid => Base64.strict_encode64(key.to_der))
    ENV["#{prefix}_JWT_PUBLIC_KEYSET"] = JSON.generate("keys" => [public_jwk])
  end

  def install_local_surface_jwt_key!(namespace, kid)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_jwk = JWT::JWK.new(key, kid).export.transform_keys(&:to_s).merge(
      "alg" => "ES384",
      "use" => "sig",
      "state" => "active",
    )
    ENV["JWT_#{namespace}_ACTIVE_KID"] = kid
    ENV["JWT_#{namespace}_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    ENV["JWT_#{namespace}_PUBLIC_KEYSET"] = JSON.generate("keys" => [public_jwk])
  end

  install_test_jwt_keyset!("AUTH", "#{Rails.env}-auth-es384-a")
  install_test_jwt_keyset!("PREFERENCE", "#{Rails.env}-preference-es384-a")
  Jit::Security::Jwt::Registry::SURFACE_NAMESPACES.each do |namespace|
    install_local_surface_jwt_key!(namespace, "#{Rails.env}-#{namespace.downcase.tr("_", "-")}-es384-a")
  end
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
