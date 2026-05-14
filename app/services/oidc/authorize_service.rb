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
      validate!
      code_record = issue_authorization_code!
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

    def validate!
      raise ArgumentError, "response_type must be 'code'" unless params[:response_type] == "code"
      raise ArgumentError, "client_id is required" if params[:client_id].blank?
      raise ArgumentError, "redirect_uri is required" if params[:redirect_uri].blank?
      raise ArgumentError, "code_challenge is required" if params[:code_challenge].blank?
      raise ArgumentError, "code_challenge_method must be 'S256'" unless params[:code_challenge_method] == "S256"

      @client = Oidc::ClientRegistry.find!(params[:client_id])

      return if Oidc::ClientRegistry.valid_redirect_uri?(params[:client_id], params[:redirect_uri])

      raise Oidc::ClientRegistry::InvalidRedirectUri,
            "redirect_uri is not registered for client #{params[:client_id]}"

    end

    def issue_authorization_code!
      if operator_client?
        TokenRecord.connected_to(role: :writing) do
          OperatorAuthorizationCode.issue!(
            staff: resource,
            client_id: params[:client_id],
            redirect_uri: params[:redirect_uri],
            code_challenge: params[:code_challenge],
            code_challenge_method: params[:code_challenge_method],
            scope: params[:scope],
            state: params[:state],
            nonce: params[:nonce],
            auth_method: auth_method,
            acr: acr,
          )
        end
      elsif visitor_client?
        SymbolRecord.connected_to(role: :writing) do
          VisitorAuthorizationCode.issue!(
            visitor: resource,
            client_id: params[:client_id],
            redirect_uri: params[:redirect_uri],
            code_challenge: params[:code_challenge],
            code_challenge_method: params[:code_challenge_method],
            scope: params[:scope],
            state: params[:state],
            nonce: params[:nonce],
            auth_method: auth_method,
            acr: acr,
          )
        end
      else
        MarkRecord.connected_to(role: :writing) do
          UserAuthorizationCode.issue!(
            user: resource,
            client_id: params[:client_id],
            redirect_uri: params[:redirect_uri],
            code_challenge: params[:code_challenge],
            code_challenge_method: params[:code_challenge_method],
            scope: params[:scope],
            state: params[:state],
            nonce: params[:nonce],
            auth_method: auth_method,
            acr: acr,
          )
        end
      end
    end

    def operator_client?
      %w(operator staff).include?(@client.resource_type)
    end

    def visitor_client?
      %w(visitor customer).include?(@client.resource_type)
    end

    def build_success_redirect(code_record)
      uri = URI.parse(code_record.redirect_uri)
      query_params = URI.decode_www_form(uri.query || "")
      query_params << ["code", code_record.code]
      query_params << ["state", code_record.state] if code_record.state.present?
      uri.query = URI.encode_www_form(query_params)

      Result.new(success: true, redirect_url: uri.to_s, error: nil, error_description: nil)
    end

    def failure(error, description)
      Result.new(success: false, redirect_url: nil, error: error, error_description: description)
    end
  end
end
