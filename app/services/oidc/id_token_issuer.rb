# typed: false
# frozen_string_literal: true

module Oidc
  class IdTokenIssuer < ApplicationService
    TOKEN_TTL = 5.minutes
    TOKEN_TYPE = "id-token+jwt"

    def initialize(resource:, client:, nonce:, issued_at: Time.current, expires_at: nil, acr: nil, amr: nil,
                   jwt_issuer_id: nil, issuer: nil, subject: nil, sid: nil, auth_time: nil, step_up_until: nil)
      super()
      @resource = resource
      @client = client
      @nonce = nonce
      @issued_at = issued_at
      @expires_at = expires_at || (issued_at + TOKEN_TTL)
      @acr = acr
      @amr = amr
      @jwt_issuer_id = jwt_issuer_id
      @issuer = issuer
      @subject = subject
      @sid = sid
      @auth_time = auth_time
      @step_up_until = step_up_until
    end

    def call
      raise ArgumentError, "nonce is required" if nonce.blank?

      Jit::Security::Jwt::Keyring.encode(payload, issuer_id: resolved_jwt_issuer_id)
    end

    private

    attr_reader :resource, :client, :nonce, :issued_at, :expires_at, :acr, :amr, :jwt_issuer_id,
                :issuer, :subject, :sid, :auth_time, :step_up_until

    def payload
      {
        "iss" => issuer.presence || Oidc::Issuer.for_client(client),
        "sub" => subject.presence || Oidc::Subject.for(resource, resource_type: token_resource_type),
        "aud" => client.client_id,
        "exp" => Integer(expires_at.to_i),
        "iat" => Integer(issued_at.to_i),
        "jti" => Jit::Security::Jwt::JtiGenerator.generate,
        "typ" => TOKEN_TYPE,
        "act" => token_resource_type,
        "sid" => sid.presence || SecureRandom.urlsafe_base64(18),
        "nonce" => nonce,
        "acr" => acr.presence || "aal1",
      }.tap do |claims|
        claims["amr"] = Array(amr) if amr.present?
        claims["auth_time"] = Integer(auth_time.to_i) if auth_time.present?
        claims["step_up_until"] = Integer(step_up_until.to_i) if step_up_until.present?
      end
    end

    def token_resource_type
      return "operator" if %w(operator staff).include?(client.resource_type)
      return "visitor" if %w(visitor customer).include?(client.resource_type)

      "client"
    end

    def resolved_jwt_issuer_id
      jwt_issuer_id.presence || Oidc::Issuer.jwt_issuer_id_for_client(client)
    end
  end
end
