# typed: false
# frozen_string_literal: true

class PalmAccessTokenAuthenticator < ApplicationService
  AUDIENCE = "palm-api"
  REQUIRED_SCOPE = "palm.read"
  ALLOWED_CLIENT_IDS = %w(app-ios-rp app-android-rp).freeze
  RESOURCE_TYPE = "client"

  Result =
    Data.define(:success, :payload, :resource, :error) do
      def success? = success
    end

  def initialize(access_token:, host:, authorization_scheme:)
    super()
    @access_token = access_token
    @host = host
    @authorization_scheme = authorization_scheme
  end

  def call
    return failure("invalid_token") if access_token.blank?
    return failure("invalid_token") unless authorization_scheme.to_s.casecmp?("Bearer")

    payload = AuthenticationTokenService.decode(
      access_token,
      host: host,
      resource_type: RESOURCE_TYPE,
      issuer: OidcIssuer.for_resource_type(RESOURCE_TYPE),
      audiences: [AUDIENCE],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(RESOURCE_TYPE),
    )
    return failure("invalid_token") unless payload
    return failure("insufficient_scope") unless scope_allowed?(payload)
    return failure("invalid_token") unless allowed_client_id?(payload)

    resource = find_resource(payload)
    return failure("invalid_token") unless resource&.active?
    return failure("invalid_token") if resource.respond_to?(:admin_locked?) && resource.admin_locked?
    if resource.respond_to?(:access_token_stale_for_administrative_lock?) &&
        resource.access_token_stale_for_administrative_lock?(payload)
      return failure("invalid_token")
    end

    Result.new(success: true, payload: payload, resource: resource, error: nil)
  end

  private

  attr_reader :access_token, :host, :authorization_scheme

  def scope_allowed?(payload)
    Array(AuthorizationTokenClaims.scopes(payload)).include?(REQUIRED_SCOPE)
  end

  def allowed_client_id?(payload)
    ALLOWED_CLIENT_IDS.include?(AuthorizationTokenClaims.client_id(payload).to_s)
  end

  def find_resource(payload)
    public_id = OidcSubject.public_id_from(AuthorizationTokenClaims.subject(payload), resource_type: RESOURCE_TYPE)
    return nil if public_id.blank?

    AppPrincipalRecord.connected_to(role: :reading) do
      Client.find_by(public_id: public_id)
    end
  end

  def failure(error)
    Result.new(success: false, payload: nil, resource: nil, error: error)
  end
end
