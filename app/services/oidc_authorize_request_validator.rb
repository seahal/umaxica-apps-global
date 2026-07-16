# typed: false
# frozen_string_literal: true

class OidcAuthorizeRequestValidator < ApplicationService
  class InvalidScope < ArgumentError; end

  ValidatedRequest = Data.define(:client, :scope)

  def initialize(params:, resource:, resource_type: nil)
    super()
    @params = params
    @resource = resource
    @given_resource_type = resource_type
  end

  def call
    validate_required_params!
    client = find_client!
    scope = validate_scope_allowlist!(client)
    validate_redirect_uri!
    validate_state_and_nonce!
    validate_resource!
    ValidatedRequest.new(client: client, scope: scope)
  end

  private

  attr_reader :params, :resource, :given_resource_type

  def validate_required_params!
    raise ArgumentError, "response_type must be 'code'" unless params[:response_type] == "code"
    raise ArgumentError, "client_id is required" if client_id.blank?
    raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?
    raise ArgumentError, "code_challenge is required" if params[:code_challenge].blank?
    raise ArgumentError, "code_challenge_method must be 'S256'" unless params[:code_challenge_method] == "S256"
    raise ArgumentError, "scope must include openid" unless scope_includes_openid?
  end

  def validate_state_and_nonce!
    raise ArgumentError, "state is required" if params[:state].blank?
    raise ArgumentError, "nonce is required" if params[:nonce].blank?
  end

  def validate_resource!
    return if resource.blank?

    raise ArgumentError, "resource is not active" unless resource&.active?
  end

  def validate_scope_allowlist!(client)
    requested_scopes = scope_tokens
    invalid_scopes = requested_scopes - client.allowed_scopes

    raise InvalidScope, "scope is not allowed for client #{client.client_id}" if invalid_scopes.any?

    requested_scopes.join(" ")
  end

  def find_client!
    OidcClientRegistry.find!(client_id)
  end

  def validate_redirect_uri!
    return if OidcClientRegistry.valid_redirect_uri?(client_id, redirect_uri, resource_type: resource_type)

    raise OidcClientRegistry::InvalidRedirectUri,
          "redirect_uri is not registered for client #{client_id} in realm #{resource_type}"
  end

  def resource_type
    return given_resource_type.to_s if given_resource_type.present?

    case resource
    when ::Operator then "operator"
    when ::Visitor then "visitor"
    else "client"
    end
  end

  def client_id
    params[:client_id]
  end

  def redirect_uri
    params[:redirect_uri]
  end

  def scope_includes_openid?
    scope_tokens.include?("openid")
  end

  def scope_tokens
    params[:scope].to_s.split
  end
end
