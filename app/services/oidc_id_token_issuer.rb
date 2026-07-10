# typed: false
# frozen_string_literal: true

class OidcIdTokenIssuer < ApplicationService
  TOKEN_TTL = SecurityJwtOidcIdTokenCodec::TOKEN_TTL
  TOKEN_TYPE = SecurityJwtOidcIdTokenCodec::TOKEN_TYPE

  def initialize(resource:, client:, nonce:, issued_at: Time.current.utc, expires_at: nil, acr: nil, amr: nil,
                 jwt_issuer_id: nil, issuer: nil, subject: nil, sid: nil, auth_time: nil, step_up_until: nil)
    super()
    @resource = resource
    @client = client
    @nonce = nonce
    @issued_at = issued_at.utc
    @expires_at = (expires_at || (@issued_at + TOKEN_TTL)).utc
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
    raise ArgumentError, "invalid id token time ordering" if issued_at > expires_at

    SecurityJwtOidcIdTokenCodec.encode(payload, issuer_id: resolved_jwt_issuer_id)
  end

  private

  attr_reader :resource, :client, :nonce, :issued_at, :expires_at, :acr, :amr, :jwt_issuer_id,
              :issuer, :subject, :sid, :auth_time, :step_up_until

  def payload
    SecurityJwtOidcIdTokenCodec.build_payload(
      resource: resource,
      client: client,
      nonce: nonce,
      issued_at: issued_at,
      expires_at: expires_at,
      acr: acr,
      amr: amr,
      issuer: issuer,
      subject: subject,
      sid: sid,
      auth_time: auth_time,
      step_up_until: step_up_until,
    )
  end

  def token_resource_type
    SecurityJwtOidcIdTokenCodec.resource_type_for_client(client)
  end

  def resolved_jwt_issuer_id
    jwt_issuer_id.presence || OidcIssuer.jwt_issuer_id_for_client(client)
  end
end
