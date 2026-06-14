# typed: false
# frozen_string_literal: true

class OidcTokenExchangeService < ApplicationService
  Result =
    Data.define(:success, :token_response, :error, :error_description) do
      def success? = success
    end

  def initialize(grant_type:, code:, redirect_uri:, client_id:, client_secret: nil, code_verifier:,
                 client_assertion_type: nil, client_assertion: nil,
                 dpop_proof: nil, token_endpoint_uri: nil, request_method: "POST")
    super()
    @grant_type = grant_type
    @code = code
    @redirect_uri = redirect_uri
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion_type = client_assertion_type
    @client_assertion = client_assertion
    @code_verifier = code_verifier
    @dpop_proof = dpop_proof
    @token_endpoint_uri = token_endpoint_uri
    @request_method = request_method
  end

  def call
    return failure("invalid_request", "grant_type must be 'authorization_code'") unless valid_grant_type?
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?

    authorization_code = find_code
    return failure("invalid_grant", "Authorization code not found") unless authorization_code

    code_failure = validate_code(authorization_code)
    return code_failure if code_failure

    pkce_failure = verify_pkce(authorization_code)
    return pkce_failure if pkce_failure

    dpop_jkt = validate_dpop_proof(authorization_code)
    return dpop_jkt if dpop_jkt.is_a?(Result)

    consume_and_issue_tokens!(authorization_code, dpop_jkt: dpop_jkt)
  end

  private

  attr_reader :grant_type, :code, :redirect_uri, :client_id, :client_secret, :client_assertion_type,
              :client_assertion, :code_verifier,
              :dpop_proof, :token_endpoint_uri, :request_method

  def valid_grant_type?
    grant_type == "authorization_code"
  end

  def authenticated_client?
    client = OidcClientRegistry.find(client_id)
    return false unless client

    return false if client_id.blank?
    return authenticated_client_assertion? if client_assertion.present? || client_assertion_type.present?
    return public_client_authenticated? if client.public_client?

    OidcClientRegistry.authenticate(client_id, client_secret)
  end

  def public_client_authenticated?
    client_secret.blank?
  end

  def authenticated_client_assertion?
    return false unless client_assertion_type == OidcClientAssertionJwt::ASSERTION_TYPE
    return false if token_endpoint_uri.blank?

    OidcClientRegistry.authenticate_assertion(
      client_id,
      client_assertion,
      token_url: token_endpoint_uri,
    )
  end

  def find_code
    OrgTicketRecord.connected_to(role: :writing) do
      OperatorAuthorizationCode.lock.find_by(code: code)
    end || ComTicketRecord.connected_to(role: :writing) do
      VisitorAuthorizationCode.lock.find_by(code: code)
    end || AppTicketRecord.connected_to(role: :writing) do
      ClientAuthorizationCode.lock.find_by(code: code)
    end
  end

  def validate_code(authorization_code)
    return failure("invalid_grant", "Authorization code expired") if authorization_code.expired?
    return failure("invalid_grant", "Authorization code already consumed") if authorization_code.consumed?
    return failure("invalid_grant", "Authorization code revoked") if authorization_code.revoked?
    return failure("invalid_request", "redirect_uri mismatch") unless authorization_code.redirect_uri == redirect_uri
    return failure("invalid_request", "client_id mismatch") unless authorization_code.client_id == client_id

    nil
  end

  def verify_pkce(authorization_code)
    return failure("invalid_request", "code_verifier is required") if code_verifier.blank?
    return nil if authorization_code.verify_pkce(code_verifier)

    failure("invalid_request", "PKCE verification failed")
  end

  def consume_and_issue_tokens!(authorization_code, dpop_jkt: nil)
    client = OidcClientRegistry.find!(client_id)
    resource = authorization_code.resource
    return failure("invalid_grant", "resource is not active") unless resource&.active?

    connection_class = connection_class_for(authorization_code)

    connection_class.connected_to(role: :writing) do
      authorization_code.consume!

      now = Time.current
      oidc_connection = OidcConnectionRecorder.call(
        resource: resource,
        client: client,
        scope: authorization_code.scope,
        used_at: now,
      )
      token_record = create_token_record!(
        client,
        resource,
        dpop_jkt: dpop_jkt,
        oidc_connection: oidc_connection,
        oidc_scope: authorization_code.scope,
      )
      refresh_plain = token_record.rotate_refresh_token!
      access_expires_at = now + AuthenticationBase::ACCESS_TOKEN_TTL

      resource_type = token_resource_type(client)
      issuer = OidcIssuer.for_client(client)
      subject = OidcSubject.for(resource, resource_type: resource_type)
      oidc_sid = token_record_oidc_sid(token_record)
      auth_time = authorization_code.created_at || now

      access_token = AuthenticationTokenService.encode(
        resource,
        host: OidcIssuer.host_for_client(client),
        session_public_id: token_record.public_id,
        oidc_sid: oidc_sid,
        oidc_jti: token_record_oidc_jti(token_record),
        resource_type: resource_type,
        expires_at: access_expires_at,
        scopes: authorization_code.scope.to_s.split,
        acr: authorization_code.acr,
        amr: Array(authorization_code.auth_method),
        dpop_jkt: dpop_jkt,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        issuer: issuer,
        audiences: [client.aud],
        subject: subject,
        auth_time: auth_time,
      )
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: client,
        nonce: authorization_code.nonce,
        issued_at: now,
        acr: authorization_code.acr,
        amr: Array(authorization_code.auth_method),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        issuer: issuer,
        subject: subject,
        sid: oidc_sid,
        auth_time: auth_time,
      )

      token_type = dpop_jkt.present? ? "DPoP" : "Bearer"

      Result.new(
        success: true,
        token_response: {
          access_token: access_token,
          token_type: token_type,
          expires_in: Integer(AuthenticationBase::ACCESS_TOKEN_TTL.to_s, 10),
          refresh_token: refresh_plain,
          id_token: id_token,
        },
        error: nil,
        error_description: nil,
      )
    end
  end

  def create_token_record!(client, resource, dpop_jkt: nil, oidc_connection: nil, oidc_scope: nil)
    oidc_attrs = {
      oidc_connection_id: oidc_connection&.id,
      oidc_client_id: client.client_id,
      oidc_scope: oidc_scope,
      oidc_sid: SecureRandom.uuid,
      oidc_jti: SecureRandom.uuid,
    }

    if operator_client?(client)
      OperatorToken.create!(
        staff: resource,
        public_id: SecureRandom.alphanumeric(21),
        discarded_at: AuthenticationBase::REFRESH_TOKEN_TTL.from_now,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
        dpop_jkt: dpop_jkt,
        **oidc_attrs,
      )
    elsif visitor_client?(client)
      VisitorToken.create!(
        visitor: resource,
        public_id: SecureRandom.alphanumeric(21),
        discarded_at: AuthenticationBase::REFRESH_TOKEN_TTL.from_now,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        dpop_jkt: dpop_jkt,
        **oidc_attrs,
      )
    else
      ClientToken.create!(
        user: resource,
        public_id: SecureRandom.alphanumeric(21),
        discarded_at: AuthenticationBase::REFRESH_TOKEN_TTL.from_now,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        dpop_jkt: dpop_jkt,
        **oidc_attrs,
      )
    end
  end

  def operator_client?(client)
    %w(operator staff).include?(client.resource_type)
  end

  def visitor_client?(client)
    %w(visitor customer).include?(client.resource_type)
  end

  def token_resource_type(client)
    return "operator" if operator_client?(client)
    return "visitor" if visitor_client?(client)

    client.resource_type
  end

  def token_record_oidc_sid(token_record)
    token_record_attribute(token_record, :oidc_sid).presence ||
      raise(ArgumentError, "OIDC token record is missing oidc_sid")
  end

  def token_record_oidc_jti(token_record)
    token_record_attribute(token_record, :oidc_jti).presence ||
      raise(ArgumentError, "OIDC token record is missing oidc_jti")
  end

  def token_record_attribute(token_record, attribute)
    return unless token_record&.has_attribute?(attribute)

    token_record.public_send(attribute)
  end

  def connection_class_for(authorization_code)
    case authorization_code
    when OperatorAuthorizationCode then OrgTicketRecord
    when VisitorAuthorizationCode then ComTicketRecord
    else AppTicketRecord
    end
  end

  def validate_dpop_proof(authorization_code)
    return nil if dpop_proof.blank?

    result = DpopProofValidator.new(
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: token_endpoint_uri.to_s,
      resource_type: resource_type_for(authorization_code),
    ).call

    return failure("invalid_request", "DPoP proof invalid: #{result.error}") unless result.valid?

    result.jkt
  end

  def resource_type_for(authorization_code)
    case authorization_code
    when OperatorAuthorizationCode then "operator"
    when VisitorAuthorizationCode then "visitor"
    else "client"
    end
  end

  def failure(error, description)
    Result.new(success: false, token_response: nil, error: error, error_description: description)
  end
end
