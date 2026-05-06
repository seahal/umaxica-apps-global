# typed: false
# frozen_string_literal: true

module Oidc
  class TokenExchangeService < ApplicationService
    Result =
      Data.define(:success, :token_response, :error, :error_description) do
        def success? = success
      end

    def initialize(grant_type:, code:, redirect_uri:, client_id:, client_secret:, code_verifier:)
      super()
      @grant_type = grant_type
      @code = code
      @redirect_uri = redirect_uri
      @client_id = client_id
      @client_secret = client_secret
      @code_verifier = code_verifier
    end

    def call
      validate_grant_type!
      authenticate_client!
      authorization_code = find_and_validate_code!
      verify_pkce!(authorization_code)
      consume_and_issue_tokens!(authorization_code)
    rescue ArgumentError => e
      failure("invalid_request", e.message)
    rescue ActiveRecord::RecordNotFound
      failure("invalid_grant", "Authorization code not found")
    rescue RuntimeError => e
      failure("invalid_grant", e.message)
    end

    private

    attr_reader :grant_type, :code, :redirect_uri, :client_id, :client_secret, :code_verifier

    def validate_grant_type!
      raise ArgumentError, "grant_type must be 'authorization_code'" unless grant_type == "authorization_code"
    end

    def authenticate_client!
      return if Oidc::ClientRegistry.authenticate(client_id, client_secret)

      raise ArgumentError, "Client authentication failed"

    end

    def find_and_validate_code!
      authorization_code =
        TokenRecord.connected_to(role: :writing) do
          StaffAuthorizationCode.lock.find_by(code: code)
        end || MarkRecord.connected_to(role: :writing) do
          UserAuthorizationCode.lock.find_by(code: code)
        end

      raise ActiveRecord::RecordNotFound unless authorization_code

      raise RuntimeError, "Authorization code expired" if authorization_code.expired?
      raise RuntimeError, "Authorization code already consumed" if authorization_code.consumed?
      raise RuntimeError, "Authorization code revoked" if authorization_code.revoked?
      raise ArgumentError, "redirect_uri mismatch" unless authorization_code.redirect_uri == redirect_uri
      raise ArgumentError, "client_id mismatch" unless authorization_code.client_id == client_id

      authorization_code
    end

    def verify_pkce!(authorization_code)
      raise ArgumentError, "code_verifier is required" if code_verifier.blank?

      return if authorization_code.verify_pkce(code_verifier)

      raise ArgumentError, "PKCE verification failed"

    end

    def consume_and_issue_tokens!(authorization_code)
      client = Oidc::ClientRegistry.find!(client_id)
      resource = authorization_code.is_a?(StaffAuthorizationCode) ? authorization_code.staff : authorization_code.user

      connection_class = authorization_code.is_a?(StaffAuthorizationCode) ? TokenRecord : MarkRecord

      connection_class.connected_to(role: :writing) do
        authorization_code.consume!

        token_record = create_token_record!(client, resource)
        refresh_plain = token_record.rotate_refresh_token!
        now = Time.current
        access_expires_at = now + Authentication::Base::ACCESS_TOKEN_TTL

        id_host =
          if client.resource_type == "staff"
            ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          else
            ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          end

        access_token = Auth::TokenService.encode(
          resource,
          host: id_host,
          session_public_id: token_record.public_id,
          resource_type: client.resource_type,
          expires_at: access_expires_at,
          acr: authorization_code.acr,
          amr: Array(authorization_code.auth_method),
        )

        Result.new(
          success: true,
          token_response: {
            access_token: access_token,
            token_type: "Bearer",
            expires_in: Integer(Authentication::Base::ACCESS_TOKEN_TTL.to_s, 10),
            refresh_token: refresh_plain,
          },
          error: nil,
          error_description: nil,
        )
      end
    end

    def create_token_record!(client, resource)
      if client.resource_type == "staff"
        StaffToken.create!(
          staff: resource,
          public_id: SecureRandom.alphanumeric(21),
          refresh_expires_at: Authentication::Base::REFRESH_TOKEN_TTL.from_now,
          status: "active",
        )
      else
        UserToken.create!(
          user: resource,
          public_id: SecureRandom.alphanumeric(21),
          refresh_expires_at: Authentication::Base::REFRESH_TOKEN_TTL.from_now,
          status: "active",
        )
      end
    end

    def failure(error, description)
      Result.new(success: false, token_response: nil, error: error, error_description: description)
    end
  end
end
