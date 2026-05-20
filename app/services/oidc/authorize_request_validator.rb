# typed: false
# frozen_string_literal: true

module Oidc
  class AuthorizeRequestValidator < ApplicationService
    def initialize(params:, resource:)
      super()
      @params = params
      @resource = resource
    end

    def call
      validate_required_params!
      client = find_client!
      validate_redirect_uri!
      validate_state_and_nonce!
      validate_resource!
      client
    end

    private

    attr_reader :params, :resource

    def validate_required_params!
      raise ArgumentError, "response_type must be 'code'" unless params[:response_type] == "code"
      raise ArgumentError, "client_id is required" if client_id.blank?
      raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?
      raise ArgumentError, "code_challenge is required" if params[:code_challenge].blank?
      raise ArgumentError, "code_challenge_method must be 'S256'" unless params[:code_challenge_method] == "S256"
    end

    def validate_state_and_nonce!
      raise ArgumentError, "state is required" if params[:state].blank?
      raise ArgumentError, "nonce is required" if params[:nonce].blank?
    end

    def validate_resource!
      raise ArgumentError, "resource is not active" unless resource&.active?
    end

    def find_client!
      Oidc::ClientRegistry.find!(client_id)
    end

    def validate_redirect_uri!
      return if Oidc::ClientRegistry.valid_redirect_uri?(client_id, redirect_uri)

      raise Oidc::ClientRegistry::InvalidRedirectUri,
            "redirect_uri is not registered for client #{client_id}"
    end

    def client_id
      params[:client_id]
    end

    def redirect_uri
      params[:redirect_uri]
    end
  end
end
