# typed: false
# frozen_string_literal: true

class OidcTokenRevoker < ApplicationService
  Result =
    Data.define(:success, :error, :error_description) do
      def success? = success
    end

  def initialize(token:, client_id:, client_secret:, token_type_hint: nil, host: nil)
    super()
    @token = token
    @client_id = client_id
    @client_secret = client_secret
    @token_type_hint = token_type_hint
    @host = host
  end

  def call
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?

    revoke_refresh_token || revoke_access_token
    Result.new(success: true, error: nil, error_description: nil)
  end

  private

  attr_reader :token, :client_id, :client_secret, :token_type_hint, :host

  def authenticated_client?
    OidcClientRegistry.authenticate(client_id, client_secret)
  end

  def revoke_refresh_token
    return false if token.blank?

    parsed = ClientToken.parse_refresh_token(token)
    return false unless parsed

    public_id, verifier = parsed
    token_record = find_usage_by_public_id(public_id, resource_type: client_resource_type)
    return false unless token_record
    return false unless token_record.oidc_client_id == client_id
    return false unless token_record.refresh_token_digest_matches?(verifier)

    token_record.revoke!
    true
  end

  def revoke_access_token
    client = OidcClientRegistry.find(client_id)
    return false unless client

    payload = AuthenticationTokenService.decode_allow_expired(
      token,
      host: host.presence || OidcIssuer.host_for_client(client),
      resource_type: client_resource_type,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )
    return false unless payload

    token_record = find_usage_by_sid(
      client_resource_type,
      payload["sid"],
    ) || find_token_by_sid(client_resource_type, payload["sid"])
    return false unless token_record&.oidc_client_id == client_id
    return false unless token_jti_matches?(token_record, payload)

    token_record.revoke!
    true
  end

  def find_usage_by_public_id(public_id, resource_type:)
    context, usage_class = usage_context_and_class(resource_type)

    context.connected_to(role: :writing) { usage_class.find_by(public_id: public_id) }
  end

  def find_usage_by_sid(resource_type, sid)
    return if sid.blank?

    context, usage_class = usage_context_and_class(resource_type)

    context.connected_to(role: :writing) do
      usage_class.find_by(public_id: sid)
    end
  end

  def find_token_by_sid(resource_type, sid)
    return if sid.blank?

    context, token_class = token_context_and_class(resource_type)

    context.connected_to(role: :writing) do
      token_class.find_by(oidc_sid: sid)
    end
  end

  def token_jti_matches?(token_record, payload)
    return false unless token_record.has_attribute?(:oidc_jti)
    return false if token_record.oidc_jti.blank?

    expected = token_record.oidc_jti.to_s
    actual = payload["jti"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def token_context_and_class(resource_type)
    case resource_type
    when "operator" then [OrgTicketRecord, OperatorToken]
    when "visitor" then [ComTicketRecord, VisitorToken]
    else [AppTicketRecord, ClientToken]
    end
  end

  def usage_context_and_class(resource_type)
    case resource_type
    when "operator" then [OrgTicketRecord, OperatorTokenUsage]
    when "visitor" then [ComTicketRecord, VisitorTokenUsage]
    else [AppTicketRecord, ClientTokenUsage]
    end
  end

  def client_resource_type
    @client_resource_type ||= OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(client_id))
  end

  def failure(error, description)
    Result.new(success: false, error: error, error_description: description)
  end
end
