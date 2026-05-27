# typed: false
# frozen_string_literal: true

module Oidc
  class AuthorizeService < ApplicationService
    Result =
      Data.define(:success, :redirect_url, :error, :error_description) do
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
      client = validate_request!
      code_record = issue_authorization_code!(client)
      build_success_redirect(code_record)
    rescue Oidc::ClientRegistry::ClientNotFound => e
      failure("unauthorized_client", e.message)
    rescue Oidc::ClientRegistry::InvalidRedirectUri, ArgumentError => e
      failure("invalid_request", e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure("server_error", e.message)
    end

    private

    attr_reader :params, :resource, :auth_method, :acr

    def validate_request!
      Oidc::AuthorizeRequestValidator.call(params: params, resource: resource)
    end

    def issue_authorization_code!(client)
      Oidc::AuthorizationCodeIssuer.call(
        client: client,
        params: params,
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

      Result.new(success: true, redirect_url: uri.to_s, error: nil, error_description: nil)
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
      Result.new(success: false, redirect_url: nil, error: error, error_description: description)
    end
  end
end
