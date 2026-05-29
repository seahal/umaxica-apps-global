# typed: false
# frozen_string_literal: true

module Oidc
  class AccessTokenAuthenticator < ApplicationService
    Result =
      Data.define(:success, :payload, :token, :resource, :error) do
        def success? = success
      end

    def initialize(access_token:, resource_type:, host:)
      super()
      @access_token = access_token
      @resource_type = Oidc::Subject.normalize_resource_type(resource_type)
      @host = host
    end

    def call
      return failure("invalid_token") if access_token.blank?

      payload = Authentication::TokenService.decode(
        access_token,
        host: host,
        resource_type: resource_type,
        issuer: Oidc::Issuer.for_resource_type(resource_type),
        audiences: Oidc::ClientRegistry.audiences_for_resource_type(resource_type),
        jwt_issuer_id: Oidc::Issuer.jwt_issuer_id_for_resource_type(resource_type),
      )
      return failure("invalid_token") unless payload

      token = find_token(payload)
      return failure("invalid_token") unless token&.active?
      return failure("invalid_token") unless token_belongs_to_audience?(token, payload)
      return failure("invalid_token") unless token_jti_matches?(token, payload)
      return failure("insufficient_scope") unless token_scope_allows_userinfo?(payload)

      resource = token_resource(token)
      return failure("invalid_token") unless resource&.active?
      return failure("invalid_token") unless token_subject_matches?(resource, payload)

      Result.new(success: true, payload: payload, token: token, resource: resource, error: nil)
    end

    private

    attr_reader :access_token, :resource_type, :host

    def find_token(payload)
      token_class = token_class_for_resource_type
      sid = payload["sid"].to_s
      return if sid.blank?

      token_context.connected_to(role: :reading) do
        token_class.find_by(oidc_sid: sid)
      end
    end

    def token_belongs_to_audience?(token, payload)
      return false unless token.respond_to?(:oidc_client_id)

      client = Oidc::ClientRegistry.find(token.oidc_client_id)
      return false unless client
      return false unless Oidc::Issuer.resource_type_for_client(client) == resource_type

      Array(payload["aud"]).include?(client.aud)
    end

    def token_jti_matches?(token, payload)
      return true unless token.has_attribute?(:oidc_jti)
      return true if token.oidc_jti.blank?

      expected = token.oidc_jti.to_s
      actual = payload["jti"].to_s
      return false unless expected.bytesize == actual.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def token_scope_allows_userinfo?(payload)
      Array(payload["scp"]).include?("openid")
    end

    def token_subject_matches?(resource, payload)
      expected = Oidc::Subject.for(resource, resource_type: resource_type)
      actual = payload["sub"].to_s
      return false unless expected.bytesize == actual.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def token_resource(token)
      case resource_type
      when "operator" then token.staff
      when "visitor" then token.visitor
      else token.user
      end
    end

    def token_class_for_resource_type
      case resource_type
      when "operator" then OperatorToken
      when "visitor" then VisitorToken
      else ClientToken
      end
    end

    def token_context
      case resource_type
      when "operator" then OrgTicketRecord
      when "visitor" then ComTicketRecord
      else AppTicketRecord
      end
    end

    def failure(error)
      Result.new(success: false, payload: nil, token: nil, resource: nil, error: error)
    end
  end
end
