# typed: false
# frozen_string_literal: true

module Oidc
  class IdTokenIssuer < ApplicationService
    TOKEN_TTL = 5.minutes
    TOKEN_TYPE = "JWT"

    def initialize(resource:, client:, nonce:, issued_at: Time.current, expires_at: nil, acr: nil, amr: nil)
      super()
      @resource = resource
      @client = client
      @nonce = nonce
      @issued_at = issued_at
      @expires_at = expires_at || (issued_at + TOKEN_TTL)
      @acr = acr
      @amr = amr
    end

    def call
      raise ArgumentError, "nonce is required" if nonce.blank?

      Jit::Security::Jwt::Keyring.encode(payload)
    end

    private

    attr_reader :resource, :client, :nonce, :issued_at, :expires_at, :acr, :amr

    def payload
      {
        "iss" => issuer,
        "sub" => resource.id,
        "aud" => client.client_id,
        "exp" => Integer(expires_at.to_i),
        "iat" => Integer(issued_at.to_i),
        "jti" => Jit::Security::Jwt::JtiGenerator.generate,
        "typ" => TOKEN_TYPE,
        "act" => token_resource_type,
        "sid" => SecureRandom.urlsafe_base64(18),
        "nonce" => nonce,
        "acr" => acr.presence || "aal1",
      }.tap do |claims|
        claims["amr"] = Array(amr) if amr.present?
      end
    end

    def issuer
      Authentication::Base::JwtConfiguration.issuer(token_resource_type)
    end

    def token_resource_type
      return "operator" if %w(operator staff).include?(client.resource_type)
      return "visitor" if %w(visitor customer).include?(client.resource_type)

      "client"
    end
  end
end
