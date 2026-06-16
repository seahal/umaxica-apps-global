# typed: false
# frozen_string_literal: true

class OidcAuthorizeService < ApplicationService
  Result =
    Data.define(:success, :redirect_url, :redirect_uri, :error, :error_description) do
      def success? = success
    end

  def initialize(params:, resource:, auth_method: nil, acr: nil)
    super()
    @params = params
    @resource = resource
    @auth_method = auth_method
    @acr = acr
  end

  def call
    validation = validate_request!
    code_record = issue_authorization_code!(validation)
    build_success_redirect(code_record)
  rescue OidcClientRegistry::ClientNotFound => e
    failure("unauthorized_client", e.message)
  rescue OidcAuthorizeRequestValidator::InvalidScope => e
    failure("invalid_scope", e.message)
  rescue OidcClientRegistry::InvalidRedirectUri, ArgumentError => e
    failure("invalid_request", e.message)
  rescue ActiveRecord::RecordInvalid => e
    failure("server_error", e.message)
  end

  private

  attr_reader :params, :resource, :auth_method, :acr

  def validate_request!
    OidcAuthorizeRequestValidator.call(params: params, resource: resource)
  end

  def issue_authorization_code!(client)
    OidcAuthorizationCodeIssuer.call(
      client: client.client,
      params: params.merge(scope: client.scope),
      resource: resource,
      auth_method: auth_method,
      acr: acr,
    )
  end

  def build_success_redirect(code_record)
    uri = URI.parse(code_record.redirect_uri)
    normalize_default_port!(uri)
    query_params = URI.decode_www_form(uri.query || "")
    query_params << ["code", code_record.code]
    query_params << ["state", code_record.state] if code_record.state.present?
    uri.query = URI.encode_www_form(query_params)

    Result.new(
      success: true, redirect_url: uri.to_s, redirect_uri: code_record.redirect_uri, error: nil,
      error_description: nil,
    )
  end

  def normalize_default_port!(uri)
    default_port =
      case uri.scheme
      when "https" then 443
      when "http" then 80
      end

    uri.port = nil if default_port.present? && uri.port == default_port
  end

  def failure(error, description)
    Result.new(success: false, redirect_url: nil, redirect_uri: nil, error: error, error_description: description)
  end
end
